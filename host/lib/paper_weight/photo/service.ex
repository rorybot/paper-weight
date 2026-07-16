defmodule PaperWeight.Photo.Service do
  @moduledoc """
  GenServer: local photo library with skip / keep / reprint rotation.

  Not registered in Application yet (orchestrator wave). Start in tests via
  `start_supervised!` or `start_link/1`.
  """

  use GenServer

  alias PaperWeight.Photo.{Config, Library, Rotate, Snapshot}

  @type state :: %{
          config: Config.t(),
          rotate: Rotate.t(),
          gen: non_neg_integer(),
          tick_ms: pos_integer() | :infinity,
          now_ms_fn: (-> non_neg_integer()),
          scan_fn: (Config.t() -> [Library.entry()])
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

  @spec get_snapshot(GenServer.server()) :: {:ok, Snapshot.t()} | {:error, :no_snapshot}
  def get_snapshot(server), do: GenServer.call(server, :get_snapshot)

  @spec get_gen(GenServer.server()) :: non_neg_integer()
  def get_gen(server), do: GenServer.call(server, :get_gen)

  @spec skip(GenServer.server()) :: {:ok, Snapshot.t()}
  def skip(server), do: GenServer.call(server, :skip)

  @spec keep(GenServer.server()) :: {:ok, Snapshot.t()}
  def keep(server), do: GenServer.call(server, :keep)

  @spec rescan(GenServer.server()) :: {:ok, Snapshot.t()}
  def rescan(server), do: GenServer.call(server, :rescan)

  @impl true
  def init(opts) do
    config = Config.new(Keyword.get(opts, :config_opts, opts))
    tick_ms = Keyword.get(opts, :tick_ms, config.tick_ms)
    auto_tick? = Keyword.get(opts, :auto_tick, true)
    now_ms_fn = Keyword.get(opts, :now_ms_fn, &default_now_ms/0)
    scan_fn = Keyword.get(opts, :scan_fn, &Library.scan/1)

    now_ms = now_ms_fn.()
    photos = scan_fn.(config)
    rotate = Rotate.new(photos, config.reprint_interval_min, now_ms)

    state = %{
      config: config,
      rotate: rotate,
      gen: 1,
      tick_ms: tick_ms,
      now_ms_fn: now_ms_fn,
      scan_fn: scan_fn
    }

    if auto_tick? and is_integer(tick_ms) and tick_ms > 0 do
      schedule(tick_ms)
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:get_snapshot, _from, state) do
    {:reply, {:ok, snapshot(state)}, state}
  end

  def handle_call(:get_gen, _from, state), do: {:reply, state.gen, state}

  def handle_call(:skip, _from, state) do
    now_ms = state.now_ms_fn.()
    rotate = Rotate.skip(state.rotate, now_ms)
    state = %{state | rotate: rotate, gen: state.gen + 1}
    {:reply, {:ok, snapshot(state, now_ms)}, state}
  end

  def handle_call(:keep, _from, state) do
    rotate = Rotate.keep(state.rotate)
    state = %{state | rotate: rotate, gen: state.gen + 1}
    {:reply, {:ok, snapshot(state)}, state}
  end

  def handle_call(:rescan, _from, state) do
    now_ms = state.now_ms_fn.()
    photos = state.scan_fn.(state.config)
    rotate = Rotate.rescan(state.rotate, photos, now_ms)
    state = %{state | rotate: rotate, gen: state.gen + 1}
    {:reply, {:ok, snapshot(state, now_ms)}, state}
  end

  @impl true
  def handle_info(:tick, state) do
    now_ms = state.now_ms_fn.()
    before = state.rotate
    rotate = Rotate.tick(before, now_ms)

    state =
      if rotate == before do
        state
      else
        %{state | rotate: rotate, gen: state.gen + 1}
      end

    if is_integer(state.tick_ms) and state.tick_ms > 0 do
      schedule(state.tick_ms)
    end

    {:noreply, state}
  end

  defp snapshot(state, now_ms \\ nil) do
    now = now_ms || state.now_ms_fn.()
    source = state.config.source_label || state.config.library_dir || "local library"

    Snapshot.assemble(%{
      state: state.rotate,
      now_ms: now,
      source: source,
      art_pbm_base64: nil
    })
  end

  defp schedule(ms), do: Process.send_after(self(), :tick, ms)

  defp default_now_ms do
    System.system_time(:millisecond)
  end
end
