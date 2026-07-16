defmodule PaperWeight.Feed.AccentTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Feed.Accent

  test "accent assignment is stable and independent of input order" do
    handles = ["@NASA", "internetarchive", "@publicdomainrev"]

    first = Accent.assign_accents(handles)
    second = Accent.assign_accents(Enum.reverse(handles))

    assert first == second
    assert first["@nasa"] == Accent.accent_for("NASA")
    assert map_size(first) == 3
  end
end
