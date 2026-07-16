defmodule PaperWeight.Spotify.SnapshotTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Spotify.Snapshot

  test "assemble produces the full NowPlayingSnapshotV1 field set" do
    snap =
      Snapshot.assemble(%{
        track: %{
          title: "Track Title",
          artist: "Artist One, Artist Two",
          album: "Album Name",
          duration_ms: 200_000,
          progress_ms: 45_000
        },
        queue: [%{title: "Next Track", artist: "Someone"}],
        volume_level: 42,
        stale: false,
        art_pbm_base64: nil
      })

    for key <- Snapshot.required_keys() do
      assert Map.has_key?(snap, key), "missing key #{key}"
    end

    assert snap["stale"] == false
    assert snap["track"]["title"] == "Track Title"
    assert snap["track"]["art_pbm_base64"] == nil
    assert snap["queue"] == [%{"title" => "Next Track", "artist" => "Someone"}]
    assert snap["volume"] == %{"level" => 42}
    assert snap["lyrics"] == nil
    assert is_binary(snap["as_of"])
  end

  test "assemble handles no track playing (track: nil)" do
    snap = Snapshot.assemble(%{track: nil, queue: [], volume_level: 10})

    assert snap["track"] == nil
    assert snap["queue"] == []
  end

  test "assemble handles :none sentinel for no track" do
    snap = Snapshot.assemble(%{track: :none, queue: [], volume_level: 10})

    assert snap["track"] == nil
  end

  test "mark_stale flips the stale flag and keeps the rest of the snapshot" do
    snap = Snapshot.assemble(%{track: nil, queue: [], volume_level: 10, stale: false})
    stale_snap = Snapshot.mark_stale(snap)

    assert stale_snap["stale"] == true
    assert stale_snap["volume"] == snap["volume"]
  end
end
