defmodule PaperWeight.ApplicationWeatherTest do
  use ExUnit.Case, async: false

  test "test env disables weather service under the app supervisor" do
    assert Application.get_env(:paper_weight_host, :weather_service) == :disabled
    assert Process.whereis(PaperWeight.Weather.Service) == nil
  end

  test "weather service child_spec is startable with injected mock client" do
    http = fn _url, _headers -> {:error, :econnrefused} end

    {:ok, pid} =
      start_supervised(
        {PaperWeight.Weather.Service,
         [
           http_get: http,
           auto_refresh: false,
           refresh_ms: :infinity,
           name: :weather_wire_test,
           # Location not in repo defaults — tests must inject URLs or WEATHER_LAT/LON.
           nws_points_url: "https://api.weather.gov/points/0,0",
           openuv_uv_url: "https://api.openuv.io/api/v1/uv?lat=0&lng=0",
           openuv_forecast_url: "https://api.openuv.io/api/v1/forecast?lat=0&lng=0"
         ]}
      )

    assert Process.alive?(pid)
    assert {:error, :no_snapshot} = PaperWeight.Weather.Service.get_snapshot(pid)
  end
end
