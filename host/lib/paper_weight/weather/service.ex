defmodule PaperWeight.Weather.Service do
  @moduledoc """
  GenServer: periodic weather refresh with last-good cache.

  On fetch failure keeps the previous snapshot and sets `stale: true`.

  Registered in `PaperWeight.Application` as
  `{PaperWeight.Weather.Service, [name: PaperWeight.Weather.Service]}`.
  Disable in tests via `config :paper_weight_host, weather_service: :disabled`.
  """

  use GenServer

  alias PaperWeight.Weather.{Config, Fetch, Snapshot}

  @type state :: %{
          config: Config.t(),
          snapshot: Snapshot.t() | nil,
          gen: non_neg_integer(),
          http_get: Fetch.http_get(),
          refresh_ms: pos_integer() | :infinity
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

  @spec refresh_now(GenServer.server()) :: {:ok, Snapshot.t()} | {:error, term()}
  def refresh_now(server), do: GenServer.call(server, :refresh_now, 30_000)

  @impl true
  def init(opts) do
    config = Config.new(Keyword.get(opts, :config_opts, opts))
    http_get = Keyword.get(opts, :http_get, Fetch.default_http_get())
    refresh_ms = Keyword.get(opts, :refresh_ms, config.refresh_ms)
    auto_refresh? = Keyword.get(opts, :auto_refresh, true)

    state = %{
      config: config,
      snapshot: nil,
      gen: 0,
      http_get: http_get,
      refresh_ms: refresh_ms
    }

    state = do_refresh(state)

    if auto_refresh? and is_integer(refresh_ms) and refresh_ms > 0 do
      schedule(refresh_ms)
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:get_snapshot, _from, state) do
    reply =
      case state.snapshot do
        nil -> {:error, :no_snapshot}
        snap -> {:ok, snap}
      end

    {:reply, reply, state}
  end

  def handle_call(:get_gen, _from, state), do: {:reply, state.gen, state}

  def handle_call(:refresh_now, _from, state) do
    state = do_refresh(state)

    reply =
      case state.snapshot do
        nil -> {:error, :no_snapshot}
        snap -> if snap["stale"], do: {:error, :stale_only}, else: {:ok, snap}
      end

    # If we have a stale last-good after failure, still return {:ok, snap} for callers
    # that want cache — refresh_now returns error only when nothing to serve.
    reply =
      case {reply, state.snapshot} do
        {{:error, :stale_only}, snap} when is_map(snap) -> {:ok, snap}
        other -> other
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    state = do_refresh(state)

    if is_integer(state.refresh_ms) and state.refresh_ms > 0 do
      schedule(state.refresh_ms)
    end

    {:noreply, state}
  end

  defp do_refresh(state) do
    case Fetch.fetch_snapshot(state.config, state.http_get) do
      {:ok, snapshot} ->
        %{state | snapshot: snapshot, gen: state.gen + 1}

      {:error, _reason} ->
        case state.snapshot do
          nil ->
            state

          snap ->
            %{state | snapshot: Snapshot.mark_stale(snap)}
        end
    end
  end

  defp schedule(ms), do: Process.send_after(self(), :refresh, ms)
end
