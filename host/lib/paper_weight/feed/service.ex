defmodule PaperWeight.Feed.Service do
  @moduledoc """
  Periodically refreshes and atomically replaces the cached feed snapshot.
  """

  use GenServer

  alias PaperWeight.Feed.{Config, Fetch, Snapshot}

  defstruct [:config, :fetcher, :timer_ref, :last_error, gen: 0, snapshot: nil]

  @type state :: %__MODULE__{
          config: Config.t(),
          fetcher: (Config.t() -> {:ok, Snapshot.t()} | {:error, term()}),
          timer_ref: reference() | nil,
          last_error: term() | nil,
          gen: non_neg_integer(),
          snapshot: Snapshot.t()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options \\ []) do
    name = Keyword.get(options, :name, __MODULE__)
    GenServer.start_link(__MODULE__, options, server_options(name))
  end

  @spec current(GenServer.server()) :: %{
          gen: non_neg_integer(),
          snapshot: Snapshot.t(),
          last_error: term() | nil
        }
  def current(server \\ __MODULE__), do: GenServer.call(server, :current)

  @spec refresh(GenServer.server()) :: map()
  def refresh(server \\ __MODULE__), do: GenServer.call(server, :refresh)

  @impl true
  def init(options) do
    config = Keyword.get_lazy(options, :config, &Config.from_env/0)
    fetcher = Keyword.get(options, :fetcher, &Fetch.fetch_snapshot/1)

    state = %__MODULE__{
      config: config,
      fetcher: fetcher,
      snapshot: Snapshot.empty_stale()
    }

    {:ok, state |> refresh_now() |> schedule_refresh()}
  end

  @impl true
  def handle_call(:current, _from, state) do
    {:reply, public_state(state), state}
  end

  def handle_call(:refresh, _from, state) do
    refreshed = refresh_now(state)
    {:reply, public_state(refreshed), refreshed}
  end

  @impl true
  def handle_info(:refresh, state) do
    refreshed = state |> Map.put(:timer_ref, nil) |> refresh_now() |> schedule_refresh()
    {:noreply, refreshed}
  end

  defp refresh_now(%__MODULE__{} = state) do
    case state.fetcher.(state.config) do
      {:ok, snapshot} ->
        %{state | snapshot: snapshot, gen: state.gen + 1, last_error: nil}

      {:error, reason} ->
        stale_snapshot = Snapshot.mark_stale(state.snapshot)
        changed? = not state.snapshot.stale

        %{
          state
          | snapshot: stale_snapshot,
            gen: state.gen + if(changed?, do: 1, else: 0),
            last_error: reason
        }
    end
  end

  defp schedule_refresh(%__MODULE__{config: config} = state) do
    %{state | timer_ref: Process.send_after(self(), :refresh, config.refresh_ms)}
  end

  defp public_state(state) do
    %{gen: state.gen, snapshot: state.snapshot, last_error: state.last_error}
  end

  defp server_options(nil), do: []
  defp server_options(name), do: [name: name]
end
