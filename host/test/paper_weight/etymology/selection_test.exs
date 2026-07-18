defmodule PaperWeight.Etymology.SelectionTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Etymology.Selection

  defp entries, do: [:a, :b, :c]

  test "pick/2 is stable for a given date" do
    date = ~D[2026-07-15]
    assert Selection.pick(entries(), date) == Selection.pick(entries(), date)
  end

  test "consecutive days step through the corpus and wrap" do
    picks =
      for offset <- 0..3 do
        Selection.pick(entries(), Date.add(~D[2026-07-15], offset))
      end

    # three-entry corpus: index advances by one each day, wrapping on day 3.
    assert Enum.at(picks, 3) == Enum.at(picks, 0)
    assert length(Enum.uniq(Enum.take(picks, 3))) == 3
  end

  test "index_for/2 stays within corpus bounds" do
    for offset <- 0..30 do
      idx = Selection.index_for(Date.add(~D[2026-07-01], offset), 3)
      assert idx in 0..2
    end
  end

  test "single-entry corpus always yields that entry" do
    assert Selection.pick([:only], ~D[2026-07-15]) == :only
  end
end
