defmodule PaperWeight.Gateway.PublisherTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Gateway.Publisher

  @ts 1_721_150_000_000

  test "always emits a playlist stub envelope even with everything disabled" do
    envelopes = Publisher.envelopes(%{}, @ts)

    assert [%{channel: :playlist, v: 1, ts: @ts, gen: 1, payload: payload}] = envelopes
    assert %{as_of: _, stale: false, playlists: []} = payload
  end

  test "emits an envelope per channel with a valid payload/gen" do
    inputs = %{
      weather: {:ok, %{"temp" => 70}, 3},
      spotify: {:ok, %{"track" => "a"}, 7},
      feed: {:ok, %{posts: []}, 1},
      photo: {:ok, %{"caption" => "x"}, 2}
    }

    envelopes = Publisher.envelopes(inputs, @ts)
    by_channel = Map.new(envelopes, &{&1.channel, &1})

    assert by_channel[:weather] == %{v: 1, ts: @ts, channel: :weather, gen: 3, payload: %{"temp" => 70}}
    assert by_channel[:now_playing].gen == 7
    assert by_channel[:feed].gen == 1
    assert by_channel[:photo].gen == 2
    assert Map.has_key?(by_channel, :playlist)
    assert map_size(by_channel) == 5
  end

  test "disabled channel is omitted" do
    inputs = %{weather: :disabled, spotify: :disabled, feed: :disabled, photo: :disabled}
    envelopes = Publisher.envelopes(inputs, @ts)

    assert Enum.map(envelopes, & &1.channel) == [:playlist]
  end

  test "missing/errored channel (e.g. no_snapshot yet) is omitted, not crashed" do
    inputs = %{
      weather: {:error, :no_snapshot},
      spotify: {:ok, %{}, 1},
      feed: :disabled,
      photo: {:error, :service_unavailable}
    }

    envelopes = Publisher.envelopes(inputs, @ts)

    assert Enum.map(envelopes, & &1.channel) |> Enum.sort() == [:now_playing, :playlist]
  end
end
