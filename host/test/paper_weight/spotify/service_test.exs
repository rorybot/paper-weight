defmodule PaperWeight.Spotify.ServiceTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Spotify.Service

  @fixture_dir Path.join([__DIR__, "fixtures"])

  defp fixture(name), do: File.read!(Path.join(@fixture_dir, name))

  defp ok_http_post do
    fn _url, _headers, _body -> {:ok, 200, fixture("token.json")} end
  end

  defp ok_http(opts \\ []) do
    fail_all? = Keyword.get(opts, :fail_all, false)
    volume_ref = Keyword.get(opts, :volume_ref)

    fn
      _method, _url, _headers, _body when fail_all? ->
        {:error, :econnrefused}

      :get, url, _headers, nil ->
        cond do
          String.contains?(url, "currently-playing") ->
            {:ok, 200, fixture("currently_playing.json")}

          String.contains?(url, "/me/player/queue") ->
            {:ok, 200, fixture("queue.json")}

          String.contains?(url, "/me/playlists") ->
            {:ok, 200, fixture("playlists.json")}

          String.contains?(url, "/me/player") ->
            {:ok, 200, fixture("player.json")}
        end

      :put, url, _headers, _body ->
        if volume_ref, do: Agent.update(volume_ref, fn _ -> extract_volume(url) end)
        {:ok, 204, ""}
    end
  end

  defp extract_volume(url) do
    [_, qs] = String.split(url, "?", parts: 2)
    %{"volume_percent" => v} = URI.decode_query(qs)
    String.to_integer(v)
  end

  defp start_service(opts \\ []) do
    default_opts = [
      config_opts: [client_id: "cid", client_secret: "sec", refresh_token: "rtok"],
      http_post: ok_http_post(),
      http: ok_http(),
      auto_poll: false
    ]

    start_supervised!({Service, Keyword.merge(default_opts, opts)})
  end

  test "now_playing returns a snapshot matching NowPlayingSnapshotV1 after init poll" do
    server = start_service()

    assert {:ok, snap} = Service.now_playing(server)
    assert snap["track"]["title"] == "Track Title"
    assert snap["volume"] == %{"level" => 42}
    assert snap["stale"] == false
  end

  test "queue returns the display-only queue list" do
    server = start_service()

    assert {:ok, queue} = Service.queue(server)

    assert queue == [
             %{"id" => "queueid000000next01", "title" => "Next Track", "artist" => "Someone"},
             %{
               "id" => "queueid000another002",
               "title" => "Another Track",
               "artist" => "Someone Else, Third"
             }
           ]
  end

  test "keeps last-good snapshot and marks stale when poll fails" do
    server = start_service()
    assert {:ok, snap} = Service.now_playing(server)
    assert snap["stale"] == false

    :sys.replace_state(server, fn state -> %{state | http: ok_http(fail_all: true)} end)
    assert {:ok, stale_snap} = Service.refresh_now(server)

    assert stale_snap["stale"] == true
    assert stale_snap["track"] == snap["track"]
  end

  test "recovers from stale back to fresh and advances gen after a later successful poll" do
    server = start_service()
    assert {:ok, snap} = Service.now_playing(server)
    assert snap["stale"] == false
    gen_before = Service.get_gen(server)

    :sys.replace_state(server, fn state -> %{state | http: ok_http(fail_all: true)} end)
    assert {:ok, stale_snap} = Service.refresh_now(server)
    assert stale_snap["stale"] == true
    assert Service.get_gen(server) == gen_before

    :sys.replace_state(server, fn state -> %{state | http: ok_http()} end)
    assert {:ok, recovered_snap} = Service.refresh_now(server)

    assert recovered_snap["stale"] == false
    assert Service.get_gen(server) == gen_before + 1
  end

  test "recovers stale playlists back to fresh and advances playlist gen after later success" do
    server = start_service()
    assert {:ok, _snap} = Service.playlists(server)
    gen_before = Service.get_playlist_gen(server)

    :sys.replace_state(server, fn state -> %{state | http: ok_http(fail_all: true)} end)
    assert {:ok, stale_snap} = Service.refresh_playlists(server)
    assert stale_snap.stale == true
    assert Service.get_playlist_gen(server) == gen_before

    :sys.replace_state(server, fn state -> %{state | http: ok_http()} end)
    assert {:ok, recovered_snap} = Service.refresh_playlists(server)

    assert recovered_snap.stale == false
    assert Service.get_playlist_gen(server) == gen_before + 1
  end

  test "set_volume applies a positive delta and clamps at 100" do
    {:ok, ref} = Agent.start_link(fn -> nil end)
    server = start_service(http: ok_http(volume_ref: ref))

    assert {:ok, 100} = Service.set_volume(server, 90)
    assert Agent.get(ref, & &1) == 100
  end

  test "set_volume applies a negative delta and clamps at 0" do
    {:ok, ref} = Agent.start_link(fn -> nil end)
    server = start_service(http: ok_http(volume_ref: ref))

    assert {:ok, 0} = Service.set_volume(server, -100)
    assert Agent.get(ref, & &1) == 0
  end

  test "set_volume applies a small delta relative to cached level" do
    {:ok, ref} = Agent.start_link(fn -> nil end)
    server = start_service(http: ok_http(volume_ref: ref))

    assert {:ok, 47} = Service.set_volume(server, 5)
    assert Agent.get(ref, & &1) == 47
  end

  test "play_playlist dispatches the selected id through the authenticated client" do
    {:ok, ref} = Agent.start_link(fn -> nil end)

    http = fn
      :get, url, headers, body ->
        ok_http().(:get, url, headers, body)

      :put, url, _headers, body ->
        Agent.update(ref, fn _ -> {url, body} end)
        {:ok, 204, ""}
    end

    server = start_service(http: http)

    assert :ok = Service.play_playlist(server, "abc123")
    assert {url, ~s({"context_uri":"spotify:playlist:abc123"})} = Agent.get(ref, & &1)
    assert String.ends_with?(url, "/me/player/play")
  end

  test "playlists returns a PlaylistSnapshotV1 and advances playlist gen on refresh" do
    server = start_service()

    assert {:ok, snap} = Service.playlists(server)
    assert snap.stale == false

    assert [%{id: "37i9dQZF1DXcBWIGoYBM5M", name: "Today's Top Hits", cover_pbm_base64: nil} | _] =
             snap.playlists

    assert Service.get_playlist_gen(server) == 1

    assert {:ok, snap2} = Service.refresh_playlists(server)
    assert snap2.stale == false
    assert Service.get_playlist_gen(server) == 2
  end

  test "keeps last-good playlists and marks stale when playlist poll fails" do
    server = start_service()
    assert {:ok, snap} = Service.playlists(server)
    assert snap.stale == false

    :sys.replace_state(server, fn state -> %{state | http: ok_http(fail_all: true)} end)
    assert {:ok, stale_snap} = Service.refresh_playlists(server)

    assert stale_snap.stale == true
    assert stale_snap.playlists == snap.playlists
    # gen does not advance on failure
    assert Service.get_playlist_gen(server) == 1
  end

  test "no generic play/pause/skip/previous public API exists on the service" do
    exports = Service.__info__(:functions) |> Keyword.keys()

    refute :play in exports
    refute :pause in exports
    refute :skip in exports
    refute :previous in exports
  end
end
