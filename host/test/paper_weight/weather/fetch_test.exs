defmodule PaperWeight.Weather.FetchTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Weather
  alias PaperWeight.Weather.{Config, Fetch, Snapshot}

  @fixture_dir Path.join([__DIR__, "fixtures"])

  defp fixture(name), do: File.read!(Path.join(@fixture_dir, name))

  defp mock_http(opts \\ []) do
    fail_all? = Keyword.get(opts, :fail_all, false)

    fn url, headers ->
      cond do
        fail_all? ->
          {:error, :econnrefused}

        String.contains?(url, "api.open-meteo.com") ->
          assert_header(headers, "User-Agent")
          {:ok, fixture("open_meteo_forecast.json")}

        true ->
          {:error, {:unexpected_url, url}}
      end
    end
  end

  defp assert_header(headers, name) do
    assert Enum.any?(headers, fn {k, v} -> k == name and is_binary(v) and v != "" end),
           "missing header #{name}"
  end

  test "fetch_snapshot assembles full snapshot from mocked Open-Meteo response" do
    config =
      Config.new(
        location_label: "Exampleville, EX",
        open_meteo_url: "https://api.open-meteo.com/v1/forecast?latitude=0&longitude=0"
      )

    assert {:ok, snap} = Fetch.fetch_snapshot(config, mock_http())

    for key <- Snapshot.required_keys() do
      assert Map.has_key?(snap, key)
    end

    assert snap["location_label"] == "Exampleville, EX"
    assert snap["stale"] == false
    assert snap["current"]["temp_f"] == 88
    assert snap["current"]["summary"] == "Clear"
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
               [open_meteo_url: "https://api.open-meteo.com/v1/forecast?latitude=1&longitude=2"],
               mock_http()
             )

    assert snap["uv"]["grade"] == "extreme"
  end

  test "network failure surfaces as error" do
    config =
      Config.new(open_meteo_url: "https://api.open-meteo.com/v1/forecast?latitude=1&longitude=2")

    assert {:error, _} = Fetch.fetch_snapshot(config, mock_http(fail_all: true))
  end

  test "malformed (non-JSON) response surfaces as error, not a partial snapshot" do
    config =
      Config.new(open_meteo_url: "https://api.open-meteo.com/v1/forecast?latitude=1&longitude=2")

    malformed_http = fn _url, _headers -> {:ok, "not json"} end

    assert {:error, _} = Fetch.fetch_snapshot(config, malformed_http)
  end

  test "well-formed JSON missing required forecast fields surfaces as error" do
    config =
      Config.new(open_meteo_url: "https://api.open-meteo.com/v1/forecast?latitude=1&longitude=2")

    partial_http = fn _url, _headers -> {:ok, "{\"current\":{}}"} end

    assert {:error, _} = Fetch.fetch_snapshot(config, partial_http)
  end
end
