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

        method == :get and String.contains?(url, "/me/playlists") ->
          assert String.contains?(url, "limit=")
          {:ok, 200, fixture("playlists.json")}

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
    assert Enum.any?(headers, fn {k, v} ->
             k == "Authorization" and String.starts_with?(v, "Bearer ")
           end)
  end

  test "now_playing parses title/artist/album/duration/progress" do
    assert {:ok, track} = Client.now_playing(config(), "tok", mock_http())

    assert track.title == "Track Title"
    assert track.artist == "Artist One, Artist Two"
    assert track.album == "Album Name"
    assert track.duration_ms == 200_000
    assert track.progress_ms == 45_000
  end

  test "now_playing picks the smallest album image at least as wide as the device art pane" do
    assert {:ok, track} = Client.now_playing(config(), "tok", mock_http())

    assert track.art_url == "https://i.scdn.co/image/medium"
  end

  test "now_playing falls back to the largest image when all are smaller than the art pane" do
    http = fn :get, url, _headers, nil ->
      if String.contains?(url, "currently-playing") do
        {:ok, 200,
         ~s({"progress_ms":0,"item":{"name":"T","duration_ms":1,"artists":[{"name":"A"}],
            "album":{"name":"Al","images":[
              {"url":"https://i.scdn.co/image/tiny","width":16,"height":16},
              {"url":"https://i.scdn.co/image/small","width":64,"height":64}
            ]}}})}
      end
    end

    assert {:ok, track} = Client.now_playing(config(), "tok", http)
    assert track.art_url == "https://i.scdn.co/image/small"
  end

  test "now_playing sets art_url to nil when the album has no images" do
    http = fn :get, url, _headers, nil ->
      if String.contains?(url, "currently-playing") do
        {:ok, 200,
         ~s({"progress_ms":0,"item":{"name":"T","duration_ms":1,"artists":[{"name":"A"}],
            "album":{"name":"Al"}}})}
      end
    end

    assert {:ok, track} = Client.now_playing(config(), "tok", http)
    assert track.art_url == nil
  end

  test "now_playing returns :none on empty body (nothing playing)" do
    http = fn :get, url, _headers, nil ->
      if String.contains?(url, "currently-playing"), do: {:ok, 204, ""}
    end

    assert {:ok, :none} = Client.now_playing(config(), "tok", http)
  end

  test "queue returns a bounded list of id/title/artist" do
    assert {:ok, items} = Client.queue(config(), "tok", mock_http())

    assert items == [
             %{id: "queueid000000next01", title: "Next Track", artist: "Someone"},
             %{id: "queueid000another002", title: "Another Track", artist: "Someone Else, Third"}
           ]
  end

  test "queue returns an empty list when nothing is queued" do
    http = fn :get, _url, _headers, nil -> {:ok, 200, ~s({"queue":[]})} end

    assert {:ok, []} = Client.queue(config(), "tok", http)
  end

  test "volume reads the device volume_percent" do
    assert {:ok, 42} = Client.volume(config(), "tok", mock_http())
  end

  test "set_volume PUTs the clamped level and echoes it back" do
    assert {:ok, 60} = Client.set_volume(config(), "tok", 60, mock_http())
  end

  test "play_playlist PUTs only the selected Spotify playlist context" do
    assert :ok = Client.play_playlist(config(), "tok", "abc123", mock_http())

    assert {:error, :invalid_playlist_id} =
             Client.play_playlist(config(), "tok", "bad/id", mock_http())
  end

  test "play_track PUTs only the selected track uri and rejects a malformed id" do
    http = fn :put, url, _headers, body ->
      assert String.ends_with?(url, "/me/player/play")
      assert body == ~s({"uris":["spotify:track:trk123"]})
      {:ok, 204, ""}
    end

    assert :ok = Client.play_track(config(), "tok", "trk123", http)

    assert {:error, :invalid_track_id} =
             Client.play_track(config(), "tok", "bad/id", http)
  end

  test "playlists returns id/name with null covers and skips invalid items" do
    assert {:ok, items} = Client.playlists(config(), "tok", mock_http())

    assert items == [
             %{
               id: "37i9dQZF1DXcBWIGoYBM5M",
               name: "Today's Top Hits",
               cover_pbm_base64: nil
             },
             %{
               id: "3cEYpjA9oz9GiPac4AsH4n",
               name: "Spotify Web API Testing playlist",
               cover_pbm_base64: nil
             }
           ]
  end

  test "now_playing surfaces transport errors without retry" do
    assert {:error, :econnrefused} = Client.now_playing(config(), "tok", mock_http(fail: true))
  end

  test "now_playing surfaces malformed JSON as a bad response error" do
    http = fn :get, _url, _headers, nil -> {:ok, 200, "not json"} end

    assert {:error, {:bad_now_playing_response, "not json"}} =
             Client.now_playing(config(), "tok", http)
  end

  test "now_playing surfaces a partial response missing the item field" do
    http = fn :get, _url, _headers, nil -> {:ok, 200, ~s({"progress_ms": 1000})} end

    assert {:error, {:bad_now_playing_response, _}} = Client.now_playing(config(), "tok", http)
  end

  test "queue surfaces malformed/partial responses as a bad response error" do
    http = fn :get, _url, _headers, nil -> {:ok, 200, ~s({"unexpected": true})} end

    assert {:error, {:bad_queue_response, _}} = Client.queue(config(), "tok", http)
  end

  test "playlists surfaces malformed/partial responses as a bad response error" do
    http = fn :get, _url, _headers, nil -> {:ok, 200, "{not valid json"} end

    assert {:error, {:bad_playlists_response, _}} = Client.playlists(config(), "tok", http)
  end

  test "client surfaces non-200 HTTP status errors for each read endpoint" do
    http = fn :get, _url, _headers, nil -> {:ok, 500, "server error"} end

    assert {:error, {:http_status, 500, "server error"}} = Client.now_playing(config(), "tok", http)
    assert {:error, {:http_status, 500, "server error"}} = Client.queue(config(), "tok", http)
    assert {:error, {:http_status, 500, "server error"}} = Client.playlists(config(), "tok", http)
  end

  test "set_volume surfaces a non-2xx status as an error" do
    http = fn :put, _url, _headers, _body -> {:ok, 403, ~s({"error":"forbidden"})} end

    assert {:error, {:http_status, 403, _}} = Client.set_volume(config(), "tok", 50, http)
  end

  test "no generic play/pause/skip/previous functions exist on the client" do
    exports = Client.__info__(:functions) |> Keyword.keys()

    refute :play in exports
    refute :pause in exports
    refute :skip in exports
    refute :previous in exports
  end
end
