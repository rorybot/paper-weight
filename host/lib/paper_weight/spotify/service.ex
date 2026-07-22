defmodule PaperWeight.Spotify.Service do
  @moduledoc """
  GenServer: periodic now-playing/queue/volume + playlist-list poll with last-good cache.

  On fetch failure keeps the previous snapshot and sets `stale: true`. Caches
  the volume level so `set_volume/1` (called from this GenServer, not a bare
  public function — see `set_volume/2`) can apply + clamp a delta without a
  round trip when the API call itself fails.

  Playlist list is a separate cache + generation from now-playing so the gateway
  can re-push only the `playlist` channel when the library list advances (W3-G).

  Wave 3 registers `{PaperWeight.Spotify.Service, []}` — do not add to
  Application here. **No generic** `play`, `pause`, `skip`, or `previous`; only explicit,
  device-selected targets: `play_playlist/2` (W3-E playlist grid) and `play_track/2`
  (N6 — the queue item chosen on Now Playing).
  """

  use GenServer

  alias PaperWeight.Spotify.{
    Auth,
    Client,
    Config,
    Fetch,
    Lyrics,
    PlaylistSnapshot,
    Snapshot,
    Volume
  }

  @type state :: %{
          config: Config.t(),
          snapshot: Snapshot.t() | nil,
          playlist_snapshot: PlaylistSnapshot.t() | nil,
          gen: non_neg_integer(),
          playlist_gen: non_neg_integer(),
          token: Auth.token() | nil,
          http_post: Auth.http_post(),
          http: Client.http(),
          poll_ms: pos_integer() | :infinity,
          lyrics_cache: %{String.t() => Lyrics.payload() | nil}
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)
    init_arg = Keyword.delete(opts, :name)

    if name do
      GenServer.start_link(__MODULE__, init_arg, name: name)
    else
      GenServer.start_link(__MODULE__, init_arg)
    end
  end

  @spec now_playing(GenServer.server()) :: {:ok, Snapshot.t()} | {:error, :no_snapshot}
  def now_playing(server), do: GenServer.call(server, :now_playing)

  @spec queue(GenServer.server()) :: {:ok, list()} | {:error, :no_snapshot}
  def queue(server), do: GenServer.call(server, :queue)

  @spec get_gen(GenServer.server()) :: non_neg_integer()
  def get_gen(server), do: GenServer.call(server, :get_gen)

  @spec playlists(GenServer.server()) ::
          {:ok, PlaylistSnapshot.t()} | {:error, :no_snapshot}
  def playlists(server), do: GenServer.call(server, :playlists)

  @spec get_playlist_gen(GenServer.server()) :: non_neg_integer()
  def get_playlist_gen(server), do: GenServer.call(server, :get_playlist_gen)

  @spec refresh_now(GenServer.server()) :: {:ok, Snapshot.t()} | {:error, term()}
  def refresh_now(server), do: GenServer.call(server, :refresh_now, 30_000)

  @spec refresh_playlists(GenServer.server()) ::
          {:ok, PlaylistSnapshot.t()} | {:error, term()}
  def refresh_playlists(server), do: GenServer.call(server, :refresh_playlists, 30_000)

  @doc """
  Apply a volume delta, clamp to 0..100, best-effort persist to the Spotify
  API, and cache the result. **No** play/pause counterpart exists.
  """
  @spec set_volume(GenServer.server(), integer()) :: {:ok, 0..100} | {:error, term()}
  def set_volume(server, delta) when is_integer(delta),
    do: GenServer.call(server, {:set_volume, delta})

  @spec play_playlist(GenServer.server(), String.t()) :: :ok | {:error, term()}
  def play_playlist(server, playlist_id) when is_binary(playlist_id) do
    GenServer.call(server, {:play_playlist, playlist_id})
  end

  @doc "Play the device-selected queue item (a `queue[].id`). No generic skip/next exists."
  @spec play_track(GenServer.server(), String.t()) :: :ok | {:error, term()}
  def play_track(server, track_id) when is_binary(track_id) do
    GenServer.call(server, {:play_track, track_id})
  end

  @impl true
  def init(opts) do
    config = Config.new(Keyword.get(opts, :config_opts, opts))
    http_post = Keyword.get(opts, :http_post, Auth.default_http_post())
    http = Keyword.get(opts, :http, Client.default_http())
    poll_ms = Keyword.get(opts, :poll_ms, config.poll_ms)
    auto_poll? = Keyword.get(opts, :auto_poll, true)

    state = %{
      config: config,
      snapshot: nil,
      playlist_snapshot: nil,
      gen: 0,
      playlist_gen: 0,
      token: nil,
      http_post: http_post,
      http: http,
      poll_ms: poll_ms,
      lyrics_cache: %{}
    }

    state = do_poll(state)

    if auto_poll? and is_integer(poll_ms) and poll_ms > 0 do
      schedule(poll_ms)
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:now_playing, _from, state), do: {:reply, snapshot_reply(state), state}
  def handle_call(:queue, _from, state), do: {:reply, queue_reply(state), state}
  def handle_call(:get_gen, _from, state), do: {:reply, state.gen, state}
  def handle_call(:playlists, _from, state), do: {:reply, playlist_reply(state), state}
  def handle_call(:get_playlist_gen, _from, state), do: {:reply, state.playlist_gen, state}

  def handle_call(:refresh_now, _from, state) do
    state = poll_now_playing(state)
    {:reply, snapshot_reply(state), state}
  end

  def handle_call(:refresh_playlists, _from, state) do
    state = poll_playlists(state)
    {:reply, playlist_reply(state), state}
  end

  def handle_call({:set_volume, delta}, _from, state) do
    current_level = current_volume_level(state)
    new_level = Volume.apply_delta(current_level, delta)

    persisted =
      case state.token do
        %{access_token: access_token} ->
          Client.set_volume(state.config, access_token, new_level, state.http)

        nil ->
          {:ok, new_level}
      end

    case persisted do
      {:ok, ^new_level} ->
        state = %{state | snapshot: put_volume_level(state.snapshot, new_level)}
        {:reply, {:ok, new_level}, state}

      {:error, _reason} = err ->
        # API write failed: still cache the clamped level so the UI reflects intent.
        state = %{state | snapshot: put_volume_level(state.snapshot, new_level)}
        {:reply, err, state}
    end
  end

  def handle_call({:play_playlist, playlist_id}, _from, state) do
    reply =
      case state.token do
        %{access_token: access_token} ->
          Client.play_playlist(state.config, access_token, playlist_id, state.http)

        nil ->
          {:error, :no_token}
      end

    {:reply, reply, state}
  end

  def handle_call({:play_track, track_id}, _from, state) do
    reply =
      case state.token do
        %{access_token: access_token} ->
          Client.play_track(state.config, access_token, track_id, state.http)

        nil ->
          {:error, :no_token}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_info(:poll, state) do
    state = do_poll(state)

    if is_integer(state.poll_ms) and state.poll_ms > 0 do
      schedule(state.poll_ms)
    end

    {:noreply, state}
  end

  defp do_poll(state) do
    state
    |> poll_now_playing()
    |> poll_playlists()
  end

  defp poll_now_playing(state) do
    case Fetch.fetch_snapshot(state.config, state.token, state.http_post, state.http) do
      {:ok, snapshot, token} ->
        {snapshot, lyrics_cache} = with_lyrics(snapshot, state.lyrics_cache, state.http)
        %{state | snapshot: snapshot, token: token, gen: state.gen + 1, lyrics_cache: lyrics_cache}

      {:error, _reason} ->
        case state.snapshot do
          nil -> state
          snap -> %{state | snapshot: Snapshot.mark_stale(snap)}
        end
    end
  end

  # Best-effort, cached-per-track lyrics lookup (N8): failure or no match ships
  # `lyrics: nil`, same as the frozen envelope's existing default.
  defp with_lyrics(%{"track" => nil} = snapshot, cache, _http), do: {snapshot, cache}

  defp with_lyrics(%{"track" => track} = snapshot, cache, http) do
    key = Lyrics.cache_key(track["title"], track["artist"], track["duration_ms"])

    case Map.fetch(cache, key) do
      {:ok, payload} ->
        {Map.put(snapshot, "lyrics", payload), cache}

      :error ->
        payload = fetch_lyrics(track, http)
        {Map.put(snapshot, "lyrics", payload), Map.put(cache, key, payload)}
    end
  end

  defp fetch_lyrics(track, http) do
    lyrics_track = %{
      title: track["title"],
      artist: track["artist"],
      album: track["album"],
      duration_ms: track["duration_ms"]
    }

    case Lyrics.fetch(lyrics_track, http) do
      {:ok, payload} -> payload
      {:error, _reason} -> nil
    end
  end

  defp poll_playlists(state) do
    case Fetch.fetch_playlists(state.config, state.token, state.http_post, state.http) do
      {:ok, playlist_snapshot, token} ->
        %{
          state
          | playlist_snapshot: playlist_snapshot,
            token: token,
            playlist_gen: state.playlist_gen + 1
        }

      {:error, _reason} ->
        case state.playlist_snapshot do
          nil -> state
          snap -> %{state | playlist_snapshot: PlaylistSnapshot.mark_stale(snap)}
        end
    end
  end

  defp snapshot_reply(%{snapshot: nil}), do: {:error, :no_snapshot}
  defp snapshot_reply(%{snapshot: snap}), do: {:ok, snap}

  defp playlist_reply(%{playlist_snapshot: nil}), do: {:error, :no_snapshot}
  defp playlist_reply(%{playlist_snapshot: snap}), do: {:ok, snap}

  defp queue_reply(%{snapshot: nil}), do: {:error, :no_snapshot}
  defp queue_reply(%{snapshot: snap}), do: {:ok, Map.get(snap, "queue", [])}

  defp current_volume_level(%{snapshot: %{"volume" => %{"level" => level}}}), do: level
  defp current_volume_level(_state), do: 0

  defp put_volume_level(nil, level), do: Snapshot.assemble(%{volume_level: level, stale: true})

  defp put_volume_level(snapshot, level) do
    Map.put(snapshot, "volume", %{"level" => level})
  end

  defp schedule(ms), do: Process.send_after(self(), :poll, ms)
end
