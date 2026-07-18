defmodule PaperWeight.Etymology.ServiceTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Etymology.{Corpus, Service}

  # A settable clock so tests can advance the day deterministically.
  defp clock(agent), do: fn -> Agent.get(agent, & &1) end

  defp start_clock(date) do
    {:ok, agent} = Agent.start_link(fn -> date end)
    agent
  end

  test "caches the day's tree and serves it" do
    {:ok, pid} =
      Service.start_link(entries: Corpus.entries(), today_fn: fn -> ~D[2026-07-15] end)

    assert {:ok, snap} = Service.day_tree(pid)
    assert snap["as_of"] == "2026-07-15"
    assert snap["depth"] >= 3

    # Same day -> same generation (served from cache, no rebuild).
    gen = Service.get_gen(pid)
    assert {:ok, ^snap} = Service.day_tree(pid)
    assert Service.get_gen(pid) == gen
  end

  test "rebuilds when the calendar day rolls over" do
    agent = start_clock(~D[2026-07-15])

    {:ok, pid} = Service.start_link(entries: Corpus.entries(), today_fn: clock(agent))

    {:ok, day1} = Service.day_tree(pid)
    gen1 = Service.get_gen(pid)

    Agent.update(agent, fn _ -> ~D[2026-07-16] end)

    {:ok, day2} = Service.day_tree(pid)
    assert day2["as_of"] == "2026-07-16"
    assert Service.get_gen(pid) > gen1
    refute day1 == day2
  end

  test "refresh_now rebuilds for the current day" do
    {:ok, pid} =
      Service.start_link(entries: Corpus.entries(), today_fn: fn -> ~D[2026-07-15] end)

    gen = Service.get_gen(pid)
    assert {:ok, _snap} = Service.refresh_now(pid)
    assert Service.get_gen(pid) == gen + 1
  end
end
