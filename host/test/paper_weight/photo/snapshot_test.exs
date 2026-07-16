defmodule PaperWeight.Photo.SnapshotTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Photo.{Rotate, Snapshot}

  test "assemble matches PhotoSnapshotV1 required keys" do
    photos = [
      %{id: "a", path: "/tmp/a.jpg", caption: "Alpha"},
      %{id: "b", path: "/tmp/b.jpg", caption: "Beta"}
    ]

    state = Rotate.new(photos, 5, 0)
    snap = Snapshot.assemble(%{state: state, now_ms: 0, source: "/photos", as_of: "2026-07-16T00:00:00Z"})

    for key <- Snapshot.required_keys() do
      assert Map.has_key?(snap, key), "missing #{key}"
    end

    assert snap["empty"] == false
    assert snap["index"] == 1
    assert snap["total"] == 2
    assert snap["caption"] == "Alpha"
    assert snap["id"] == "a"
    assert snap["path"] == "/tmp/a.jpg"
    assert snap["kept"] == false
    assert snap["reprints_in_min"] == 5
    assert snap["reprint_interval_min"] == 5
    assert snap["art_pbm_base64"] == nil
    assert snap["stale"] == false
    assert snap["source"] == "/photos"
  end

  test "empty library snapshot" do
    state = Rotate.new([], 5, 0)
    snap = Snapshot.assemble(%{state: state, now_ms: 0})

    assert snap["empty"] == true
    assert snap["index"] == 0
    assert snap["total"] == 0
    assert snap["id"] == nil
    assert snap["path"] == nil
    assert snap["caption"] == ""
  end

  test "mark_stale" do
    state = Rotate.new([%{id: "a", path: "/a", caption: "A"}], 5, 0)
    snap = Snapshot.assemble(%{state: state, now_ms: 0})
    assert Snapshot.mark_stale(snap)["stale"] == true
  end
end
