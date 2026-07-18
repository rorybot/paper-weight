defmodule PaperWeight.Gateway.PublisherTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Gateway.Publisher

  @ts 1_721_150_000_000

  test "emits nothing when every channel is disabled or missing" do
    assert Publisher.envelopes(%{}, @ts) == []
    assert Publisher.envelopes(%{playlist: :disabled}, @ts) == []
  end

  test "emits an envelope per channel with a valid payload/gen" do
    playlist_payload = %{
      as_of: "2026-07-18T00:00:00Z",
      stale: false,
      playlists: [%{id: "abc", name: "Drive", cover_pbm_base64: nil}]
    }

    inputs = %{
      weather: {:ok, %{"temp" => 70}, 3},
      spotify: {:ok, %{"track" => "a"}, 7},
      feed: {:ok, %{posts: []}, 1},
      photo: {:ok, %{"caption" => "x"}, 2},
      playlist: {:ok, playlist_payload, 4}
    }

    envelopes = Publisher.envelopes(inputs, @ts)
    by_channel = Map.new(envelopes, &{&1.channel, &1})

    assert by_channel[:weather] == %{
             v: 1,
             ts: @ts,
             channel: :weather,
             gen: 3,
             payload: %{"temp" => 70}
           }

    assert by_channel[:now_playing].gen == 7
    assert by_channel[:feed].gen == 1
    assert by_channel[:photo].gen == 2
    assert by_channel[:playlist].gen == 4
    assert by_channel[:playlist].payload == playlist_payload
    assert map_size(by_channel) == 5
  end

  test "disabled channel is omitted" do
    inputs = %{
      weather: :disabled,
      spotify: :disabled,
      feed: :disabled,
      photo: :disabled,
      playlist: :disabled
    }

    assert Publisher.envelopes(inputs, @ts) == []
  end

  test "missing/errored channel (e.g. no_snapshot yet) is omitted, not crashed" do
    inputs = %{
      weather: {:error, :no_snapshot},
      spotify: {:ok, %{}, 1},
      feed: :disabled,
      photo: {:error, :service_unavailable},
      playlist: {:error, :no_snapshot}
    }

    envelopes = Publisher.envelopes(inputs, @ts)

    assert Enum.map(envelopes, & &1.channel) == [:now_playing]
  end

  test "live playlist envelope carries PlaylistSnapshotV1 shape and advances gen" do
    payload_v1 = %{
      as_of: "2026-07-18T12:00:00Z",
      stale: false,
      playlists: [%{id: "pl1", name: "Morning", cover_pbm_base64: nil}]
    }

    [env1] = Publisher.envelopes(%{playlist: {:ok, payload_v1, 1}}, @ts)
    [env2] = Publisher.envelopes(%{playlist: {:ok, payload_v1, 2}}, @ts)

    assert env1.channel == :playlist
    assert env1.gen == 1
    assert env1.payload.playlists == [%{id: "pl1", name: "Morning", cover_pbm_base64: nil}]
    assert env2.gen == 2
  end
end
