defmodule PaperWeight.Weather.FetchTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Weather
  alias PaperWeight.Weather.{Config, Fetch, Snapshot}

  @fixture_dir Path.join([__DIR__, "fixtures"])

  defp fixture(name), do: File.read!(Path.join(@fixture_dir, name))

  defp mock_http(opts \\ []) do
    fail_forecast? = Keyword.get(opts, :fail_forecast, false)
    fail_all? = Keyword.get(opts, :fail_all, false)

    fn url, headers ->
      cond do
        fail_all? ->
          {:error, :econnrefused}

        # Must check gridpoints before /points/ — "gridpoints" contains "points".
        String.contains?(url, "gridpoints") and fail_forecast? ->
          {:error, :timeout}

        String.contains?(url, "gridpoints") ->
          {:ok, fixture("nws_forecast.json")}

        String.contains?(url, "/points/") ->
          assert_header(headers, "User-Agent")
          {:ok, fixture("nws_points.json")}

        String.contains?(url, "openuv") and String.contains?(url, "/uv") ->
          assert_header(headers, "x-access-token")
          {:ok, fixture("openuv_uv.json")}

        String.contains?(url, "openuv") and String.contains?(url, "forecast") ->
          {:ok, fixture("openuv_forecast.json")}

        true ->
          {:error, {:unexpected_url, url}}
      end
    end
  end

  defp assert_header(headers, name) do
    assert Enum.any?(headers, fn {k, v} -> k == name and is_binary(v) and v != "" end),
           "missing header #{name}"
  end

  test "fetch_snapshot assembles full snapshot from mocked NWS + OpenUV" do
    config =
      Config.new(
        openuv_api_key: "test-key",
        nws_points_url: "https://api.weather.gov/points/0,0",
        openuv_uv_url: "https://api.openuv.io/api/v1/uv?lat=1&lng=2",
        openuv_forecast_url: "https://api.openuv.io/api/v1/forecast?lat=1&lng=2"
      )

    assert {:ok, snap} = Fetch.fetch_snapshot(config, mock_http())

    for key <- Snapshot.required_keys() do
      assert Map.has_key?(snap, key)
    end

    assert snap["location_label"] == "Exampleville, EX"
    assert snap["stale"] == false
    assert snap["current"]["temp_f"] == 88
    assert snap["current"]["summary"] == "Sunny"
    assert snap["uv"]["index"] == 9.2
    assert snap["uv"]["grade"] == "extreme"
    assert length(snap["days5"]) == 5
    assert length(snap["days7"]) == 7
    assert length(snap["hourly_uv"]) == 6
    assert is_binary(snap["walk_verdict"])
    assert snap["walk_verdict"] == "Scorching sun — short walk, cover up."
  end

  test "public Weather.fetch_snapshot/2 uses injected client" do
    assert {:ok, snap} =
             Weather.fetch_snapshot(
               [
                 openuv_api_key: "k",
                 nws_points_url: "https://api.weather.gov/points/1,2",
                 openuv_uv_url: "https://api.openuv.io/api/v1/uv?lat=1&lng=2",
                 openuv_forecast_url: "https://api.openuv.io/api/v1/forecast?lat=1&lng=2"
               ],
               mock_http()
             )

    assert snap["uv"]["grade"] == "extreme"
  end

  test "NWS failure surfaces as error" do
    config =
      Config.new(
        openuv_api_key: "k",
        nws_points_url: "https://api.weather.gov/points/1,2"
      )

    assert {:error, _} = Fetch.fetch_snapshot(config, mock_http(fail_all: true))
  end
end
