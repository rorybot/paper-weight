defmodule PaperWeight.Gateway.StubsTest do
  use ExUnit.Case, async: false

  alias PaperWeight.Gateway.{Fixtures, Publisher, StubService, Stubs}
  alias PaperWeight.{Photo, Spotify, Weather}

  setup do
    suffix = System.unique_integer([:positive])

    names = %{
      weather: :"stub_weather_#{suffix}",
      spotify: :"stub_spotify_#{suffix}",
      photo: :"stub_photo_#{suffix}"
    }

    start_supervised!({StubService, role: :weather, name: names.weather})
    start_supervised!({StubService, role: :spotify, name: names.spotify})
    start_supervised!({StubService, role: :photo, name: names.photo})

    {:ok, names: names}
  end

  test "stub adapters expose every managed channel to Publisher", %{names: names} do
    adapters = %{
      weather: names.weather,
      spotify: names.spotify,
      photo: names.photo
    }

    inputs = PaperWeight.Gateway.Socket.collect_inputs(adapters)
    envelopes = Publisher.envelopes(inputs, 1)

    channels = envelopes |> Enum.map(& &1.channel) |> Enum.sort()

    assert channels == [:now_playing, :photo, :playlist, :weather]
    assert Enum.all?(envelopes, &(&1.gen == 1))
    assert Enum.all?(envelopes, &is_map(&1.payload))
  end

  test "service client APIs work against stubs", %{names: names} do
    assert {:ok, snap} = Weather.Service.get_snapshot(names.weather)
    assert snap["location_label"] == Fixtures.weather()["location_label"]
    assert Weather.Service.get_gen(names.weather) == 1

    assert {:ok, np} = Spotify.Service.now_playing(names.spotify)
    assert np["track"]["title"] == "Galactic"
    assert {:ok, pl} = Spotify.Service.playlists(names.spotify)
    assert length(pl.playlists) == 8
    assert Spotify.Service.get_playlist_gen(names.spotify) == 1

    assert {:ok, photo} = Photo.Service.get_snapshot(names.photo)
    assert photo["caption"] == "porch light, tuesday"
  end

  test "set_volume logs path updates level and bumps gen", %{names: names} do
    assert {:ok, 71} = Spotify.Service.set_volume(names.spotify, 1)
    assert Spotify.Service.get_gen(names.spotify) == 2
    assert {:ok, %{"volume" => %{"level" => 71}}} = Spotify.Service.now_playing(names.spotify)
  end

  test "play_playlist succeeds without a token", %{names: names} do
    assert :ok = Spotify.Service.play_playlist(names.spotify, "pl-drive")
  end

  test "Stubs.children/0 and adapters/0 use registered names" do
    children = Stubs.children()
    assert length(children) == 3
    adapters = Stubs.adapters()

    assert adapters == %{
             weather: PaperWeight.Gateway.Stubs.Weather,
             spotify: PaperWeight.Gateway.Stubs.Spotify,
             photo: PaperWeight.Gateway.Stubs.Photo
           }
  end
end
