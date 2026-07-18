defmodule PaperWeight.Spotify.ClientTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Spotify.{Client, Config}

  @fixture_dir Path.join([__DIR__, "fixtures"])

  defp fixture(name), do: File.read!(Path.join(@fixture_dir, name))

  defp config, do: Config.new(api_base: "https://api.spotify.test/v1")

  defp mock_http(opts \\ []) do
    fail? = Keyword.get(opts, :fail, false)

    fn method, url, headers, body ->
      assert_bearer_header(headers)

      cond do
        fail? ->
          {:error, :econnrefused}

        method == :get and String.contains?(url, "/me/player/currently-playing") ->
          {:ok, 200, fixture("currently_playing.json")}

        method == :get and String.contains?(url, "/me/player/queue") ->
          {:ok, 200, fixture("queue.json")}

        method == :get and String.contains?(url, "/me/player") ->
          {:ok, 200, fixture("player.json")}

        method == :put and String.contains?(url, "/me/player/volume") ->
          assert String.contains?(url, "volume_percent=")
          {:ok, 204, ""}

        method == :put and String.ends_with?(url, "/me/player/play") ->
          assert body == ~s({"context_uri":"spotify:playlist:abc123"})
          {:ok, 204, ""}

        true ->
          {:error, {:unexpected_request, method, url}}
      end
    end
  end

  defp assert_bearer_header(headers) do
    assert Enum.any?(headers, fn {k, v} -> k == "Authorization" and String.starts_with?(v, "Bearer ") end)
  end

  test "now_playing parses title/artist/album/duration/progress" do
    assert {:ok, track} = Client.now_playing(config(), "tok", mock_http())

    assert track.title == "Track Title"
    assert track.artist == "Artist One, Artist Two"
    assert track.album == "Album Name"
    assert track.duration_ms == 200_000
    assert track.progress_ms == 45_000
  end

  test "now_playing returns :none on empty body (nothing playing)" do
    http = fn :get, url, _headers, nil ->
      if String.contains?(url, "currently-playing"), do: {:ok, 204, ""}
    end

    assert {:ok, :none} = Client.now_playing(config(), "tok", http)
  end

  test "queue returns a display-only list of title/artist" do
    assert {:ok, items} = Client.queue(config(), "tok", mock_http())

    assert items == [
             %{title: "Next Track", artist: "Someone"},
             %{title: "Another Track", artist: "Someone Else, Third"}
           ]
  end

  test "volume reads the device volume_percent" do
    assert {:ok, 42} = Client.volume(config(), "tok", mock_http())
  end

  test "set_volume PUTs the clamped level and echoes it back" do
    assert {:ok, 60} = Client.set_volume(config(), "tok", 60, mock_http())
  end

  test "play_playlist PUTs only the selected Spotify playlist context" do
    assert :ok = Client.play_playlist(config(), "tok", "abc123", mock_http())
    assert {:error, :invalid_playlist_id} = Client.play_playlist(config(), "tok", "bad/id", mock_http())
  end

  test "now_playing surfaces transport errors without retry" do
    assert {:error, :econnrefused} = Client.now_playing(config(), "tok", mock_http(fail: true))
  end

  test "no generic play/pause/skip/previous functions exist on the client" do
    exports = Client.__info__(:functions) |> Keyword.keys()

    refute :play in exports
    refute :pause in exports
    refute :skip in exports
    refute :previous in exports
  end
end
