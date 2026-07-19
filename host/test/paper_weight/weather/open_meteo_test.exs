defmodule PaperWeight.Weather.OpenMeteoTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Weather.OpenMeteo

  @fixture_dir Path.join([__DIR__, "fixtures"])

  defp fixture(name) do
    body = @fixture_dir |> Path.join(name) |> File.read!()
    {:ok, decoded} = PaperWeight.Weather.JsonLite.decode(body)
    decoded
  end

  test "parses current, days, uv, and hourly from a full forecast response" do
    assert {:ok, parsed} = OpenMeteo.parse(fixture("open_meteo_forecast.json"))

    assert parsed.current == %{temp_f: 88, summary: "Clear"}
    assert parsed.uv_index == 9.2
    assert length(parsed.days) == 7
    assert length(parsed.hourly_uv) == 6

    assert Enum.at(parsed.days, 0) == %{
             date: "2026-07-16",
             high_f: 88,
             low_f: 58,
             summary: "Clear"
           }

    assert Enum.at(parsed.days, 2) == %{
             date: "2026-07-18",
             high_f: 85,
             low_f: 55,
             summary: "Light Rain"
           }

    assert Enum.at(parsed.hourly_uv, 0) == %{hour_local: "00:00", index: 0}
    assert Enum.at(parsed.hourly_uv, 5) == %{hour_local: "05:00", index: 0.1}
  end

  test "missing hourly block yields empty hourly_uv, not an error" do
    body = fixture("open_meteo_forecast.json") |> Map.delete("hourly")

    assert {:ok, parsed} = OpenMeteo.parse(body)
    assert parsed.hourly_uv == []
  end

  test "missing current block is an error" do
    body = fixture("open_meteo_forecast.json") |> Map.delete("current")

    assert {:error, :invalid_forecast} = OpenMeteo.parse(body)
  end

  test "missing daily block is an error" do
    body = fixture("open_meteo_forecast.json") |> Map.delete("daily")

    assert {:error, :invalid_forecast} = OpenMeteo.parse(body)
  end

  test "empty daily time list is an error" do
    body = put_in(fixture("open_meteo_forecast.json"), ["daily", "time"], [])

    assert {:error, :invalid_daily} = OpenMeteo.parse(body)
  end

  test "current missing temperature_2m is an error" do
    body = put_in(fixture("open_meteo_forecast.json"), ["current"], %{"weather_code" => 0})

    assert {:error, :invalid_current} = OpenMeteo.parse(body)
  end

  test "non-numeric uv_index defaults uv to 0.0" do
    body = Map.update!(fixture("open_meteo_forecast.json"), "current", &Map.delete(&1, "uv_index"))

    assert {:ok, parsed} = OpenMeteo.parse(body)
    assert parsed.uv_index == 0.0
  end

  test "not a map is an error" do
    assert {:error, :invalid_forecast} = OpenMeteo.parse("not a map")
    assert {:error, :invalid_forecast} = OpenMeteo.parse(%{})
  end
end
