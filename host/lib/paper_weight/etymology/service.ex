defmodule PaperWeight.Etymology.Service do
  @moduledoc """
  GenServer: caches the day's word-origin tree.

  Selection is deterministic per date (`Selection.pick/2`), so the snapshot is
  built once and served from cache until the calendar day rolls over, at which
  point the next `get`/`refresh` rebuilds for the new day.

  Standalone for now — **not** registered in `PaperWeight.Application` and not
  attached to any protocol channel. A future wire-up card adds:

      {PaperWeight.Etymology.Service, []}

  Injection points for tests: `:entries` (corpus) and `:today_fn` (clock).
  """

  use GenServer

  alias PaperWeight.Etymology.{Corpus, Selection, Snapshot}

  @type state :: %{
          entries: [term(), ...],
          today_fn: (-> Date.t()),
          date: Date.t() | nil,
          snapshot: Snapshot.t() | nil,
          gen: non_neg_integer()
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

  @doc "Return the cached snapshot for the current day, rebuilding if the day rolled."
  @spec day_tree(GenServer.server()) :: {:ok, Snapshot.t()} | {:error, :no_snapshot}
  def day_tree(server), do: GenServer.call(server, :day_tree)

  @doc "Monotonic generation, bumped on every rebuild (atomic snapshot swap on device)."
  @spec get_gen(GenServer.server()) :: non_neg_integer()
  def get_gen(server), do: GenServer.call(server, :get_gen)

  @doc "Force a rebuild for the current day."
  @spec refresh_now(GenServer.server()) :: {:ok, Snapshot.t()} | {:error, :no_snapshot}
  def refresh_now(server), do: GenServer.call(server, :refresh_now)

  @impl true
  def init(opts) do
    entries = Keyword.get(opts, :entries, Corpus.entries())
    today_fn = Keyword.get(opts, :today_fn, &Date.utc_today/0)

    state = %{
      entries: entries,
      today_fn: today_fn,
      date: nil,
      snapshot: nil,
      gen: 0
    }

    {:ok, build(today_fn.(), state)}
  end

  @impl true
  def handle_call(:day_tree, _from, state) do
    state = maybe_roll(state)
    {:reply, reply(state), state}
  end

  def handle_call(:get_gen, _from, state), do: {:reply, state.gen, state}

  def handle_call(:refresh_now, _from, state) do
    state = build(state.today_fn.(), state)
    {:reply, reply(state), state}
  end

  defp reply(%{snapshot: nil}), do: {:error, :no_snapshot}
  defp reply(%{snapshot: snap}), do: {:ok, snap}

  # Rebuild only when the calendar day has advanced past the cached one.
  defp maybe_roll(state) do
    today = state.today_fn.()
    if today == state.date, do: state, else: build(today, state)
  end

  defp build(date, state) do
    try do
      entry = Selection.pick(state.entries, date)
      snapshot = Snapshot.assemble(entry, date: date)
      %{state | date: date, snapshot: snapshot, gen: state.gen + 1}
    rescue
      _ ->
        # Selection/assembly is pure over in-memory data, so failure is
        # unexpected; keep the last good tree and flag it stale rather than crash.
        case state.snapshot do
          nil -> state
          snap -> %{state | snapshot: Snapshot.mark_stale(snap)}
        end
    end
  end
end
