defmodule PaperWeight.Weather.FetchTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Weather
  alias PaperWeight.Weather.{Config, Fetch, Snapshot}

  @fixture_dir Path.join([__DIR__, "fixtures"])

  defp fixture(name), do: File.read!(Path.join(@fixture_dir, name))

  defp mock_http(opts \\ []) do
    fail_all? = Keyword.get(opts, :fail_all, false)
    body_fixture = Keyword.get(opts, :fixture, "open_meteo_forecast.json")

    fn url, headers ->
      cond do
        fail_all? ->
          {:error, :econnrefused}

        String.contains?(url, "api.open-meteo.com") ->
          assert_header(headers, "User-Agent")
          {:ok, fixture(body_fixture)}

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

  test "fetch_snapshot builds the full -12h..+24h half-hourly timeline" do
    config =
      Config.new(open_meteo_url: "https://api.open-meteo.com/v1/forecast?latitude=0&longitude=0")

    assert {:ok, snap} =
             Fetch.fetch_snapshot(config, mock_http(fixture: "open_meteo_timeline.json"))

    tl = snap["timeline"]
    assert tl["step_minutes"] == 30
    # 36h window at 30-min spacing, both ends inclusive
    assert length(tl["series"]) == 73
    assert tl["now_index"] == 24

    now = Enum.at(tl["series"], tl["now_index"])
    assert now["time_local"] == "2026-07-16T14:00"

    first = hd(tl["series"])
    assert first["time_local"] == "2026-07-16T02:00"
    assert is_number(first["temp_f"])
    assert is_number(first["wind_mph"])
    assert is_number(first["precip_in"])

    assert Enum.all?(tl["series"], fn p ->
             String.ends_with?(p["time_local"], ":00") or String.ends_with?(p["time_local"], ":30")
           end)
  end

  test "partial timeline data still yields a valid series with a shifted now_index" do
    config =
      Config.new(open_meteo_url: "https://api.open-meteo.com/v1/forecast?latitude=0&longitude=0")

    assert {:ok, snap} =
             Fetch.fetch_snapshot(config, mock_http(fixture: "open_meteo_timeline_partial.json"))

    tl = snap["timeline"]
    # only 3h of history available → now_index moves earlier, series shorter
    assert tl["now_index"] == 6
    assert length(tl["series"]) == 55
    assert Enum.at(tl["series"], tl["now_index"])["time_local"] == "2026-07-16T14:00"
    assert hd(tl["series"])["time_local"] == "2026-07-16T11:00"
  end

  test "response without minutely_15 still produces a valid empty timeline" do
    config =
      Config.new(open_meteo_url: "https://api.open-meteo.com/v1/forecast?latitude=0&longitude=0")

    # open_meteo_forecast.json has no minutely_15 block
    assert {:ok, snap} = Fetch.fetch_snapshot(config, mock_http())
    assert snap["timeline"] == %{"step_minutes" => 30, "now_index" => 0, "series" => []}
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
