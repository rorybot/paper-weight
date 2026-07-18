defmodule PaperWeight.Gateway.SocketTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Feed.{Config, Service, Snapshot}
  alias PaperWeight.Gateway.Socket

  test "init pushes one frame per enabled channel plus the playlist stub, none for nil adapters" do
    feed = start_feed_service([{:ok, snapshot([post("old")])}])
    adapters = %{weather: nil, spotify: nil, feed: feed, photo: nil}

    assert {:push, frames, state} = Socket.init(adapters)

    channels = channels_of(frames)
    assert channels == [:feed, :playlist]
    assert state.gens.feed == 1
    assert state.gens.playlist == 1
  end

  test "a dead/unavailable adapter degrades to :disabled instead of crashing" do
    dead = spawn(fn -> :ok end)
    Process.sleep(5)
    refute Process.alive?(dead)

    adapters = %{weather: nil, spotify: nil, feed: dead, photo: nil}

    assert {:push, frames, _state} = Socket.init(adapters)
    assert channels_of(frames) == [:playlist]
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
    assert state2.gens.playlist == state.gens.playlist
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

  defp snapshot(posts) do
    %{Snapshot.empty_stale(~U[2026-07-16 13:00:00Z]) | stale: false, posts: posts}
  end

  defp post(id) do
    %{id: id, handle: "@ada", body: "hi", time_label: "1m", accent: PaperWeight.Feed.Accent.accent_for("@ada")}
  end
end
