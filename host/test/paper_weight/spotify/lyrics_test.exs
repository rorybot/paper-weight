defmodule PaperWeight.Spotify.LyricsTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Spotify.Lyrics

  @track %{title: "Track Title", artist: "Artist One", album: "Album Name", duration_ms: 200_000}

  describe "parse_lrc/1" do
    test "parses timed lines in ascending order" do
      lrc = """
      [ar:Artist One]
      [ti:Track Title]
      [00:12.50]First line
      [00:01.00]Second line
      """

      assert Lyrics.parse_lrc(lrc) == [
               %{t_ms: 1_000, text: "Second line"},
               %{t_ms: 12_500, text: "First line"}
             ]
    end

    test "accepts timestamps without a fractional second" do
      assert Lyrics.parse_lrc("[01:02]no fraction") == [%{t_ms: 62_000, text: "no fraction"}]
    end

    test "drops blank-text and unparseable lines" do
      lrc = """
      not a timestamp at all
      [00:05.00]
      [00:06.00]kept
      """

      assert Lyrics.parse_lrc(lrc) == [%{t_ms: 6_000, text: "kept"}]
    end
  end

  describe "fetch/2" do
    test "hit: 200 with syncedLyrics returns parsed timed lines" do
      http = fn :get, _url, [], nil ->
        {:ok, 200, ~s({"syncedLyrics": "[00:01.00]hello\\n[00:02.00]world", "id": 1})}
      end

      assert {:ok, %{lines: lines}} = Lyrics.fetch(@track, http)
      assert lines == [%{t_ms: 1_000, text: "hello"}, %{t_ms: 2_000, text: "world"}]
    end

    test "miss: 404 returns {:ok, nil}" do
      http = fn :get, _url, [], nil -> {:ok, 404, ""} end

      assert {:ok, nil} = Lyrics.fetch(@track, http)
    end

    test "malformed LRC (no parseable timed lines) returns {:ok, nil}" do
      http = fn :get, _url, [], nil ->
        {:ok, 200, ~s({"syncedLyrics": "not a valid lrc body at all"})}
      end

      assert {:ok, nil} = Lyrics.fetch(@track, http)
    end

    test "response with no syncedLyrics field returns {:ok, nil}" do
      http = fn :get, _url, [], nil -> {:ok, 200, ~s({"plainLyrics": "hello world"})} end

      assert {:ok, nil} = Lyrics.fetch(@track, http)
    end

    test "provider failure (non-200/404 status) returns {:error, _}" do
      http = fn :get, _url, [], nil -> {:ok, 500, "boom"} end

      assert {:error, {:http_status, 500, "boom"}} = Lyrics.fetch(@track, http)
    end

    test "provider failure (transport error) returns {:error, _}" do
      http = fn :get, _url, [], nil -> {:error, :econnrefused} end

      assert {:error, :econnrefused} = Lyrics.fetch(@track, http)
    end

    test "request url includes artist, track, album, and duration in seconds" do
      {:ok, agent} = Agent.start_link(fn -> nil end)

      http = fn :get, url, [], nil ->
        Agent.update(agent, fn _ -> url end)
        {:ok, 404, ""}
      end

      Lyrics.fetch(@track, http)

      url = Agent.get(agent, & &1)
      assert String.starts_with?(url, "https://lrclib.net/api/get?")
      assert url =~ "artist_name=Artist+One"
      assert url =~ "track_name=Track+Title"
      assert url =~ "album_name=Album+Name"
      assert url =~ "duration=200"
    end
  end

  test "cache_key/3 is stable per track and independent of progress" do
    assert Lyrics.cache_key("Track Title", "Artist One", 200_000) ==
             Lyrics.cache_key("Track Title", "Artist One", 200_000)

    refute Lyrics.cache_key("Track Title", "Artist One", 200_000) ==
             Lyrics.cache_key("Other Title", "Artist One", 200_000)
  end
end
