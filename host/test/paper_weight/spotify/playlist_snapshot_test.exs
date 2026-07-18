defmodule PaperWeight.Spotify.PlaylistSnapshotTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Spotify.PlaylistSnapshot

  test "assemble builds PlaylistSnapshotV1 with atom keys" do
    snap =
      PlaylistSnapshot.assemble(%{
        playlists: [
          %{id: "abc123", name: "Drive", cover_pbm_base64: nil},
          %{id: "def456", name: "Focus", cover_pbm_base64: "QUJD"}
        ],
        stale: false,
        as_of: "2026-07-18T12:00:00Z"
      })

    assert snap.as_of == "2026-07-18T12:00:00Z"
    assert snap.stale == false

    assert snap.playlists == [
             %{id: "abc123", name: "Drive", cover_pbm_base64: nil},
             %{id: "def456", name: "Focus", cover_pbm_base64: "QUJD"}
           ]
  end

  test "mark_stale flips only the stale flag" do
    snap = PlaylistSnapshot.assemble(%{playlists: [%{id: "x", name: "Y"}], stale: false})
    assert PlaylistSnapshot.mark_stale(snap).stale == true
    assert PlaylistSnapshot.mark_stale(snap).playlists == snap.playlists
  end

  test "required_keys match the frozen protocol shape" do
    assert PlaylistSnapshot.required_keys() == [:as_of, :stale, :playlists]
  end
end
