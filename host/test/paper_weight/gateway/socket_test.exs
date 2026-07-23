defmodule PaperWeight.Gateway.SocketTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Gateway.Socket
  alias PaperWeight.Photo.Service, as: PhotoService
  alias PaperWeight.Spotify.Service, as: SpotifyService

  test "init pushes one frame per enabled channel, none for nil adapters" do
    photo = start_photo_service()
    adapters = %{weather: nil, spotify: nil, photo: photo}

    assert {:push, frames, state} = Socket.init(adapters)

    channels = channels_of(frames)
    assert channels == [:photo]
    assert state.gens.photo == 1
    refute Map.has_key?(state.gens, :playlist)
  end

  test "a dead/unavailable adapter degrades to :disabled instead of crashing" do
    dead = spawn(fn -> :ok end)
    Process.sleep(5)
    refute Process.alive?(dead)

    adapters = %{weather: nil, spotify: nil, photo: dead}

    assert {:push, frames, _state} = Socket.init(adapters)
    assert channels_of(frames) == []
  end

  test "poll re-pushes only channels whose generation advanced, and skips unchanged ones" do
    photo = start_photo_service()
    adapters = %{weather: nil, spotify: nil, photo: photo}

    {:push, _frames, state} = Socket.init(adapters)

    # no change yet -> poll is a no-op
    assert {:ok, ^state} = Socket.handle_info(:poll, state)

    PhotoService.rescan(photo)

    assert {:push, frames, state2} = Socket.handle_info(:poll, state)
    assert channels_of(frames) == [:photo]
    assert state2.gens.photo == 2
  end

  test "spotify adapter supplies live playlist envelope with advancing gen" do
    spotify = start_spotify_service()
    adapters = %{weather: nil, spotify: spotify, photo: nil}

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
    state = %{adapters: %{weather: nil, spotify: nil, photo: nil}, gens: %{}}
    assert {:ok, ^state} = Socket.handle_in({"not-json", [opcode: :text]}, state)
  end

  test "handle_in routes a valid refresh intent through the configured adapter" do
    photo = start_photo_service()
    state = %{adapters: %{weather: nil, spotify: nil, photo: photo}, gens: %{}}

    frame =
      ~s({"v":1,"ts":1,"type":"intent","name":"refresh_channel","args":{"channel":"photo"}})

    assert {:ok, ^state} = Socket.handle_in({frame, [opcode: :text]}, state)
    assert PhotoService.get_gen(photo) == 2
  end

  defp channels_of(frames) do
    Enum.map(frames, fn {:text, json} ->
      [_, channel] = Regex.run(~r/"channel":"([a-z_]+)"/, json)
      String.to_atom(channel)
    end)
  end

  defp start_photo_service do
    dir =
      Path.join(
        System.tmp_dir!(),
        "paper-weight-socket-photo-" <> Integer.to_string(System.unique_integer([:positive]))
      )

    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "a.jpg"), "a")

    on_exit(fn -> File.rm_rf!(dir) end)

    start_supervised!(
      {PhotoService,
       name: nil, library_dir: dir, auto_tick: false, tick_ms: :infinity}
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

          String.contains?(url, "i.scdn.co") ->
            {:ok, 200, fixture.("album_art.jpg")}

          String.contains?(url, "lrclib.net") ->
            {:ok, 404, ""}

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
end
