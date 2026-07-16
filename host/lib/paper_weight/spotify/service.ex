defmodule PaperWeight.Spotify.Service do
  @moduledoc """
  GenServer: periodic now-playing/queue/volume poll with last-good cache.

  On fetch failure keeps the previous snapshot and sets `stale: true`. Caches
  the volume level so `set_volume/1` (called from this GenServer, not a bare
  public function — see `set_volume/2`) can apply + clamp a delta without a
  round trip when the API call itself fails.

  Wave 3 registers `{PaperWeight.Spotify.Service, []}` — do not add to
  Application here. **No** `play`, `pause`, `skip`, `previous` — volume only.
  """

  use GenServer

  alias PaperWeight.Spotify.{Auth, Client, Config, Fetch, Snapshot, Volume}

  @type state :: %{
          config: Config.t(),
          snapshot: Snapshot.t() | nil,
          gen: non_neg_integer(),
          token: Auth.token() | nil,
          http_post: Auth.http_post(),
          http: Client.http(),
          poll_ms: pos_integer() | :infinity
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

  @spec refresh_now(GenServer.server()) :: {:ok, Snapshot.t()} | {:error, term()}
  def refresh_now(server), do: GenServer.call(server, :refresh_now, 30_000)

  @doc """
  Apply a volume delta, clamp to 0..100, best-effort persist to the Spotify
  API, and cache the result. **No** play/pause counterpart exists.
  """
  @spec set_volume(GenServer.server(), integer()) :: {:ok, 0..100} | {:error, term()}
  def set_volume(server, delta) when is_integer(delta), do: GenServer.call(server, {:set_volume, delta})

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
      gen: 0,
      token: nil,
      http_post: http_post,
      http: http,
      poll_ms: poll_ms
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

  def handle_call(:refresh_now, _from, state) do
    state = do_poll(state)
    {:reply, snapshot_reply(state), state}
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

  @impl true
  def handle_info(:poll, state) do
    state = do_poll(state)

    if is_integer(state.poll_ms) and state.poll_ms > 0 do
      schedule(state.poll_ms)
    end

    {:noreply, state}
  end

  defp do_poll(state) do
    case Fetch.fetch_snapshot(state.config, state.token, state.http_post, state.http) do
      {:ok, snapshot, token} ->
        %{state | snapshot: snapshot, token: token, gen: state.gen + 1}

      {:error, _reason} ->
        case state.snapshot do
          nil -> state
          snap -> %{state | snapshot: Snapshot.mark_stale(snap)}
        end
    end
  end

  defp snapshot_reply(%{snapshot: nil}), do: {:error, :no_snapshot}
  defp snapshot_reply(%{snapshot: snap}), do: {:ok, snap}

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
