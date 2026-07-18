defmodule PaperWeight.Gateway.StubService do
  @moduledoc """
  Fixture-backed GenServer that answers the same call surface the gateway
  Socket/Intents use against real domain services.

  Start one process per channel role (`:weather | :spotify | :feed | :photo`).
  Intents on the Spotify stub log and succeed without network calls so volume
  and play-playlist round-trips are visible in the host console during smoke.
  """

  use GenServer

  require Logger

  alias PaperWeight.Gateway.Fixtures
  alias PaperWeight.Spotify.Volume

  @type role :: :weather | :spotify | :feed | :photo

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    role = Keyword.fetch!(opts, :role)
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, role, name: name)
  end

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    role = Keyword.fetch!(opts, :role)
    _name = Keyword.fetch!(opts, :name)

    %{
      id: {__MODULE__, role},
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5_000
    }
  end

  @impl true
  def init(role) do
    {:ok, initial_state(role)}
  end

  # --- Weather / Photo ---

  @impl true
  def handle_call(:get_snapshot, _from, %{role: role} = state)
      when role in [:weather, :photo] do
    {:reply, {:ok, state.snapshot}, state}
  end

  def handle_call(:get_gen, _from, %{role: role} = state)
      when role in [:weather, :photo, :spotify] do
    {:reply, state.gen, state}
  end

  def handle_call(:refresh_now, _from, %{role: :weather} = state) do
    state = %{state | gen: state.gen + 1}
    Logger.info("gateway stub: refresh_channel weather → gen=#{state.gen}")
    {:reply, {:ok, state.snapshot}, state}
  end

  def handle_call(:rescan, _from, %{role: :photo} = state) do
    state = %{state | gen: state.gen + 1}
    Logger.info("gateway stub: refresh_channel photo → gen=#{state.gen}")
    {:reply, {:ok, state.snapshot}, state}
  end

  # --- Spotify (now_playing + playlist) ---

  def handle_call(:now_playing, _from, %{role: :spotify} = state) do
    {:reply, {:ok, state.snapshot}, state}
  end

  def handle_call(:playlists, _from, %{role: :spotify} = state) do
    {:reply, {:ok, state.playlist_snapshot}, state}
  end

  def handle_call(:get_playlist_gen, _from, %{role: :spotify} = state) do
    {:reply, state.playlist_gen, state}
  end

  def handle_call(:refresh_now, _from, %{role: :spotify} = state) do
    state = %{state | gen: state.gen + 1}
    Logger.info("gateway stub: refresh_channel now_playing → gen=#{state.gen}")
    {:reply, {:ok, state.snapshot}, state}
  end

  def handle_call({:set_volume, delta}, _from, %{role: :spotify} = state)
      when is_integer(delta) do
    current =
      case state.snapshot do
        %{"volume" => %{"level" => level}} when is_integer(level) -> level
        _ -> 0
      end

    new_level = Volume.apply_delta(current, delta)
    snapshot = put_in(state.snapshot, ["volume", "level"], new_level)
    state = %{state | snapshot: snapshot, gen: state.gen + 1}

    Logger.info("gateway stub: set_volume delta=#{delta} level=#{new_level} gen=#{state.gen}")

    {:reply, {:ok, new_level}, state}
  end

  def handle_call({:play_playlist, playlist_id}, _from, %{role: :spotify} = state)
      when is_binary(playlist_id) do
    Logger.info("gateway stub: play_playlist id=#{playlist_id}")
    {:reply, :ok, state}
  end

  # --- Feed ---

  def handle_call(:current, _from, %{role: :feed} = state) do
    {:reply, %{gen: state.gen, snapshot: state.snapshot, last_error: nil}, state}
  end

  def handle_call(:refresh, _from, %{role: :feed} = state) do
    state = %{state | gen: state.gen + 1}
    Logger.info("gateway stub: refresh_channel feed → gen=#{state.gen}")
    {:reply, %{gen: state.gen, snapshot: state.snapshot, last_error: nil}, state}
  end

  def handle_call(request, _from, state) do
    Logger.warning("gateway stub: unhandled call #{inspect(request)} role=#{state.role}")
    {:reply, {:error, :unsupported}, state}
  end

  defp initial_state(:weather) do
    %{role: :weather, snapshot: Fixtures.weather(), gen: 1}
  end

  defp initial_state(:spotify) do
    %{
      role: :spotify,
      snapshot: Fixtures.now_playing(),
      playlist_snapshot: Fixtures.playlist(),
      gen: 1,
      playlist_gen: 1
    }
  end

  defp initial_state(:feed) do
    %{role: :feed, snapshot: Fixtures.feed(), gen: 1}
  end

  defp initial_state(:photo) do
    %{role: :photo, snapshot: Fixtures.photo(), gen: 1}
  end
end
