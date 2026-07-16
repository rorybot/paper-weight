defmodule PaperWeight.Feed.SnapshotTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Feed.{Config, Snapshot}

  test "filters configured handles, applies the limit, and emits the full contract" do
    config = Config.new(handles: ["@one", "@two"], limit: 2)
    now = ~U[2026-07-16 13:00:00Z]

    raw_posts = [
      %{id: "1", handle: "one", body: "First", time_label: "1m"},
      %{id: "2", handle: "ignored", body: "No", time_label: "2m"},
      %{id: "3", handle: "two", body: "Second", time_label: "3m"},
      %{id: "4", handle: "one", body: "Over limit", time_label: "4m"}
    ]

    snapshot = Snapshot.build(raw_posts, config, now)

    assert snapshot.as_of == "2026-07-16T13:00:00Z"
    refute snapshot.stale
    assert Enum.map(snapshot.posts, & &1.id) == ["1", "3"]
    assert Enum.all?(snapshot.posts, &String.starts_with?(&1.accent, "#"))
  end
end
