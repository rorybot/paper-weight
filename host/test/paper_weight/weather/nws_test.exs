defmodule PaperWeight.Weather.NwsTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Weather.{JsonLite, Nws}

  @fixture_dir Path.join([__DIR__, "fixtures"])

  defp load(name) do
    path = Path.join(@fixture_dir, name)
    assert {:ok, map} = JsonLite.decode(File.read!(path))
    map
  end

  test "parse_points extracts label and forecast URL" do
    assert {:ok, %{location_label: "Exampleville, EX", forecast_url: url}} =
             Nws.parse_points(load("nws_points.json"))

    assert String.contains?(url, "gridpoints")
  end

  test "parse_forecast builds current + multi-day" do
    assert {:ok, %{current: current, days: days}} = Nws.parse_forecast(load("nws_forecast.json"))
    assert current.temp_f == 88
    assert current.summary == "Sunny"
    days = Nws.finalize_days(days)
    assert length(days) >= 5
    assert hd(days).date == "2026-07-16"
    assert hd(days).high_f == 88
    assert hd(days).low_f == 58
  end

  test "parse_points rejects malformed/partial payload" do
    assert {:error, :invalid_points} = Nws.parse_points(%{"unexpected" => true})
    assert {:error, :missing_forecast_url} = Nws.parse_points(%{"properties" => %{}})
  end

  test "parse_forecast rejects malformed/partial payload" do
    assert {:error, :invalid_forecast} = Nws.parse_forecast(%{"unexpected" => true})
    assert {:error, :empty_forecast} = Nws.parse_forecast(%{"properties" => %{"periods" => []}})

    partial = %{
      "properties" => %{
        "periods" => [%{"startTime" => "2026-07-16T06:00:00-04:00", "isDaytime" => true}]
      }
    }

    assert {:error, :empty_forecast} = Nws.parse_forecast(partial)
  end
end
