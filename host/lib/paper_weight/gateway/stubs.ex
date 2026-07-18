defmodule PaperWeight.Gateway.Stubs do
  @moduledoc """
  W3-F smoke profile: `gateway: [stubs: :all]`.

  Starts four fixture-backed GenServers and returns adapter refs the gateway
  Socket already understands (same call surface as the real domain services).
  Enable via env `PAPER_WEIGHT_GATEWAY_STUBS=all` (see `PaperWeight.Application`).
  """

  alias PaperWeight.Gateway.StubService

  @weather_name PaperWeight.Gateway.Stubs.Weather
  @spotify_name PaperWeight.Gateway.Stubs.Spotify
  @feed_name PaperWeight.Gateway.Stubs.Feed
  @photo_name PaperWeight.Gateway.Stubs.Photo

  @doc "Child specs for the four stub adapters (stable registered names)."
  @spec children() :: [Supervisor.child_spec()]
  def children do
    [
      StubService.child_spec(role: :weather, name: @weather_name),
      StubService.child_spec(role: :spotify, name: @spotify_name),
      StubService.child_spec(role: :feed, name: @feed_name),
      StubService.child_spec(role: :photo, name: @photo_name)
    ]
  end

  @doc "Adapter map for `PaperWeight.Gateway.Endpoint` / Socket."
  @spec adapters() :: %{
          weather: module(),
          spotify: module(),
          feed: module(),
          photo: module()
        }
  def adapters do
    %{
      weather: @weather_name,
      spotify: @spotify_name,
      feed: @feed_name,
      photo: @photo_name
    }
  end
end
