defmodule PaperWeight.Dither.Cache do
  @moduledoc """
  Small OTP shell around the pure dither pipeline.

  Cache state is immutable and replaced on each call. Callers may start an
  isolated cache for tests or use the application-owned named process.
  """

  use GenServer

  @type stats :: %{entries: non_neg_integer(), hits: non_neg_integer(), misses: non_neg_integer()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options \\ []) do
    case Keyword.get(options, :name) do
      nil -> GenServer.start_link(__MODULE__, %{})
      name -> GenServer.start_link(__MODULE__, %{}, name: name)
    end
  end

  @spec fetch(GenServer.server(), term(), (-> term())) :: term()
  def fetch(cache, key, producer) when is_function(producer, 0) do
    GenServer.call(cache, {:fetch, key, producer}, :infinity)
  end

  @spec clear(GenServer.server()) :: :ok
  def clear(cache), do: GenServer.call(cache, :clear)

  @spec stats(GenServer.server()) :: stats()
  def stats(cache), do: GenServer.call(cache, :stats)

  @impl true
  def init(_options), do: {:ok, %{entries: %{}, hits: 0, misses: 0}}

  @impl true
  def handle_call({:fetch, key, producer}, _from, state) do
    case Map.fetch(state.entries, key) do
      {:ok, value} ->
        {:reply, value, %{state | hits: state.hits + 1}}

      :error ->
        value = producer.()
        entries = Map.put(state.entries, key, value)
        {:reply, value, %{state | entries: entries, misses: state.misses + 1}}
    end
  end

  def handle_call(:clear, _from, _state) do
    {:reply, :ok, %{entries: %{}, hits: 0, misses: 0}}
  end

  def handle_call(:stats, _from, state) do
    stats = %{entries: map_size(state.entries), hits: state.hits, misses: state.misses}
    {:reply, stats, state}
  end
end
