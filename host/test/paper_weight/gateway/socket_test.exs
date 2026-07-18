defmodule PaperWeight.Gateway.SocketTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Feed.{Config, Service, Snapshot}
  alias PaperWeight.Gateway.Socket
  alias PaperWeight.Spotify.Service, as: SpotifyService

  test "init pushes one frame per enabled channel, none for nil adapters" do
    feed = start_feed_service([{:ok, snapshot([post("old")])}])
    adapters = %{weather: nil, spotify: nil, feed: feed, photo: nil}

    assert {:push, frames, state} = Socket.init(adapters)

    channels = channels_of(frames)
    assert channels == [:feed]
    assert state.gens.feed == 1
    refute Map.has_key?(state.gens, :playlist)
  end

  test "a dead/unavailable adapter degrades to :disabled instead of crashing" do
    dead = spawn(fn -> :ok end)
    Process.sleep(5)
    refute Process.alive?(dead)

    adapters = %{weather: nil, spotify: nil, feed: dead, photo: nil}

    assert {:push, frames, _state} = Socket.init(adapters)
    assert channels_of(frames) == []
  end

  test "poll re-pushes only channels whose generation advanced, and skips unchanged ones" do
    feed = start_feed_service([{:ok, snapshot([post("old")])}, {:ok, snapshot([post("new")])}])
    adapters = %{weather: nil, spotify: nil, feed: feed, photo: nil}

    {:push, _frames, state} = Socket.init(adapters)

    # no change yet -> poll is a no-op
    assert {:ok, ^state} = Socket.handle_info(:poll, state)

    Service.refresh(feed)

    assert {:push, frames, state2} = Socket.handle_info(:poll, state)
    assert channels_of(frames) == [:feed]
    assert state2.gens.feed == 2
  end

  test "spotify adapter supplies live playlist envelope with advancing gen" do
    spotify = start_spotify_service()
    adapters = %{weather: nil, spotify: spotify, feed: nil, photo: nil}

    assert {:push, frames, state} = Socket.init(adapters)
    channels = channels_of(frames) |> Enum.sort()
    assert channels == [:now_playing, :playlist]
    assert state.gens.playlist == 1
    assert state.gens.now_playing == 1

    assert {:ok, ^state} = Socket.handle_info(:poll, state)

    assert {:ok, _snap} = SpotifyService.refresh_playlists(spotify)

    assert {:push, changed, state2} = Socket.handle_info(:poll, state)
    assert channels_of(changed) == [:playlist]
    assert state2.gens.playlist == 2
    assert state2.gens.now_playing == state.gens.now_playing
  end

  test "handle_in drops malformed inbound frames without changing state" do
    state = %{adapters: %{weather: nil, spotify: nil, feed: nil, photo: nil}, gens: %{}}
    assert {:ok, ^state} = Socket.handle_in({"not-json", [opcode: :text]}, state)
  end

  test "handle_in routes a valid refresh intent through the configured adapter" do
    feed = start_feed_service([{:ok, snapshot([post("old")])}, {:ok, snapshot([post("new")])}])
    state = %{adapters: %{weather: nil, spotify: nil, feed: feed, photo: nil}, gens: %{}}

    frame =
      ~s({"v":1,"ts":1,"type":"intent","name":"refresh_channel","args":{"channel":"feed"}})

    assert {:ok, ^state} = Socket.handle_in({frame, [opcode: :text]}, state)
    assert %{gen: 2, snapshot: %{posts: [%{id: "new"}]}} = Service.current(feed)
  end

  defp channels_of(frames) do
    Enum.map(frames, fn {:text, json} ->
      [_, channel] = Regex.run(~r/"channel":"([a-z_]+)"/, json)
      String.to_atom(channel)
    end)
  end

  defp start_feed_service(responses) do
    {:ok, agent} = Agent.start_link(fn -> responses end)
    fetcher = fn _config -> Agent.get_and_update(agent, fn [next | rest] -> {next, rest} end) end

    start_supervised!(
      {Service, name: nil, config: Config.new(refresh_ms: 60_000), fetcher: fetcher}
    )
  end

  defp start_spotify_service do
    fixture_dir = Path.join([__DIR__, "..", "spotify", "fixtures"])
    fixture = fn name -> File.read!(Path.join(fixture_dir, name)) end

    http_post = fn _url, _headers, _body -> {:ok, 200, fixture.("token.json")} end

    http = fn
      :get, url, _headers, nil ->
        cond do
          String.contains?(url, "currently-playing") ->
            {:ok, 200, fixture.("currently_playing.json")}

          String.contains?(url, "/me/player/queue") ->
            {:ok, 200, fixture.("queue.json")}

          String.contains?(url, "/me/playlists") ->
            {:ok, 200, fixture.("playlists.json")}

          String.contains?(url, "/me/player") ->
            {:ok, 200, fixture.("player.json")}
        end

      :put, _url, _headers, _body ->
        {:ok, 204, ""}
    end

    start_supervised!(
      {SpotifyService,
       name: nil,
       config_opts: [client_id: "cid", client_secret: "sec", refresh_token: "rtok"],
       http_post: http_post,
       http: http,
       auto_poll: false}
    )
  end

  defp snapshot(posts) do
    %{Snapshot.empty_stale(~U[2026-07-16 13:00:00Z]) | stale: false, posts: posts}
  end

  defp post(id) do
    %{
      id: id,
      handle: "@ada",
      body: "hi",
      time_label: "1m",
      accent: PaperWeight.Feed.Accent.accent_for("@ada")
    }
  end
end
