defmodule PaperWeight.Gateway.IntentsTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Gateway.Intents

  defp handlers do
    %{
      set_volume: fn server, delta -> send(server, {:set_volume, delta}) end,
      play_playlist: fn server, id -> send(server, {:play_playlist, id}) end,
      refresh_weather: fn server -> send(server, :refresh_weather) end,
      refresh_feed: fn server -> send(server, :refresh_feed) end,
      refresh_photo: fn server -> send(server, :refresh_photo) end,
      refresh_spotify: fn server -> send(server, :refresh_spotify) end
    }
  end

  test "decodes and validates each frozen v1 intent" do
    assert {:ok, {:set_volume, -5}} =
             Intents.decode(
               ~s({"v":1,"ts":1,"type":"intent","name":"set_volume","args":{"delta":-5}})
             )

    assert {:ok, {:play_playlist, "abc123"}} =
             Intents.decode(
               ~s({"v":1,"ts":1,"type":"intent","name":"play_playlist","args":{"id":"abc123"}})
             )

    assert {:ok, {:refresh_channel, "weather"}} =
             Intents.decode(
               ~s({"v":1,"ts":1,"type":"intent","name":"refresh_channel","args":{"channel":"weather"}})
             )
  end

  test "rejects malformed JSON, wrong versions, unknown names, and invalid arguments" do
    assert {:error, :invalid_json} = Intents.decode("{")
    assert {:error, :wrong_version} = Intents.decode(~s({"v":2,"type":"intent"}))

    assert {:error, {:invalid_intent, "pause"}} =
             Intents.decode(~s({"v":1,"type":"intent","name":"pause","args":{}}))

    assert {:error, {:invalid_intent, "set_volume"}} =
             Intents.decode(
               ~s({"v":1,"type":"intent","name":"set_volume","args":{"delta":"loud"}})
             )
  end

  test "dispatches valid intents to injected handlers with exact arguments" do
    adapters = %{spotify: self(), weather: self(), feed: self(), photo: self()}

    assert :ok = Intents.dispatch({:set_volume, 3}, adapters, handlers())
    assert_receive {:set_volume, 3}

    assert :ok = Intents.dispatch({:play_playlist, "abc123"}, adapters, handlers())
    assert_receive {:play_playlist, "abc123"}

    for {channel, message} <- [
          {"now_playing", :refresh_spotify},
          {"weather", :refresh_weather},
          {"feed", :refresh_feed},
          {"photo", :refresh_photo}
        ] do
      assert :ok = Intents.dispatch({:refresh_channel, channel}, adapters, handlers())
      assert_receive ^message
    end
  end

  test "disabled, dead, and intentionally unsupported targets fail without raising" do
    assert {:error, :service_disabled} =
             Intents.dispatch({:set_volume, 1}, %{spotify: nil}, handlers())

    dead = spawn(fn -> :ok end)
    Process.sleep(5)

    exiting_handlers = %{
      handlers()
      | set_volume: fn server, _delta -> GenServer.call(server, :x) end
    }

    assert {:error, :service_unavailable} =
             Intents.dispatch({:set_volume, 1}, %{spotify: dead}, exiting_handlers)

    assert {:error, {:unsupported_refresh, "etymology"}} =
             Intents.dispatch({:refresh_channel, "etymology"}, %{}, handlers())
  end
end
