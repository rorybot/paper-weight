defmodule PaperWeight.Etymology.OriginTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Etymology.Origin

  # A travailler-style spine built by hand: travel → travailen → travailler → root.
  defp travel_trace do
    root =
      Origin.new(
        form: "trepālium",
        language: "late latin",
        period: "c.400",
        gloss: "a frame of three stakes used for torture",
        components: [%{form: "trēs", gloss: "three"}, %{form: "pālus", gloss: "stake"}]
      )

    travailler =
      Origin.new(
        form: "travailler",
        language: "old french",
        period: "c.1200",
        gloss: "to labour, to suffer",
        splits_into: [%{form: "travel", note: "en"}, %{form: "travail", note: "en/fr"}],
        from: root
      )

    travailen =
      Origin.new(
        form: "travailen",
        language: "middle english",
        period: "c.1375",
        gloss: "to toil, to journey",
        from: travailler
      )

    Origin.new(
      form: "travel",
      language: "modern english",
      period: "now",
      gloss: "to journey",
      from: travailen
    )
  end

  test "new/1 enforces required keys" do
    assert_raise ArgumentError, fn -> Origin.new(form: "x", language: "y") end
  end

  test "depth counts from-hops to the terminal root" do
    assert Origin.depth(travel_trace()) == 3
  end

  test "a lone node is depth 0 and a terminal root" do
    lone = Origin.new(form: "sāl", language: "latin", gloss: "salt")
    assert Origin.depth(lone) == 0
    assert Origin.root?(lone)
  end

  test "root/1 returns the oldest node and is a terminal" do
    root = Origin.root(travel_trace())
    assert root.form == "trepālium"
    assert Origin.root?(root)
    refute Origin.root?(travel_trace())
  end

  test "ladder/1 flattens newest -> oldest" do
    forms = travel_trace() |> Origin.ladder() |> Enum.map(& &1.form)
    assert forms == ["travel", "travailen", "travailler", "trepālium"]
  end
end
