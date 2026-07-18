defmodule PaperWeight.Etymology.CorpusTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Etymology.{Corpus, Entry, Origin}

  test "entries/0 is a non-empty list of Entry structs" do
    entries = Corpus.entries()
    assert length(entries) >= 1
    assert Enum.all?(entries, &match?(%Entry{}, &1))
  end

  # Acceptance: the travailler-style fixture yields a >=3-depth tree with a
  # terminal root.
  test "travel entry yields a >=3-depth trace ending in a terminal root" do
    travel = Corpus.travel()

    assert Entry.depth(travel) >= 3

    root = Origin.root(travel.trace)
    assert Origin.root?(root)
    assert root.form == "trepālium"
    # The terminal root bottoms out in components (trēs + pālus) and has no origin.
    assert root.from == nil
    assert Enum.map(root.components, & &1.form) == ["trēs", "pālus"]
  end

  test "every entry's trace terminates at a root (no dangling spine)" do
    for entry <- Corpus.entries() do
      assert Origin.root?(Origin.root(entry.trace)),
             "#{entry.headword} trace does not terminate at a root"
    end
  end

  test "travailler stage carries splits_into branches" do
    travailler =
      Corpus.travel().trace
      |> Origin.ladder()
      |> Enum.find(&(&1.form == "travailler"))

    assert Enum.map(travailler.splits_into, & &1.form) == ["travel", "travail"]
  end
end
