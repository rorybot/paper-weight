defmodule PaperWeight.RuntimeContractTest do
  use ExUnit.Case, async: true

  alias PaperWeight.RuntimeContract

  defp getenv(values) do
    fn name -> Map.get(values, name) end
  end

  describe "missing_vars/2" do
    test "weather: everything unset reports both required vars, in order" do
      assert RuntimeContract.missing_vars(:weather, getenv(%{})) ==
               ~w(WEATHER_LAT WEATHER_LON)
    end

    test "weather: all required vars present (fake values) reports nothing missing" do
      values = %{
        "WEATHER_LAT" => "0.0",
        "WEATHER_LON" => "0.0"
      }

      assert RuntimeContract.missing_vars(:weather, getenv(values)) == []
    end

    test "an empty string counts as missing, same as unset" do
      values = %{"WEATHER_LAT" => "", "WEATHER_LON" => "0.0"}

      assert RuntimeContract.missing_vars(:weather, getenv(values)) == ["WEATHER_LAT"]
    end

    test "partial presence reports only the still-missing names" do
      values = %{"WEATHER_LAT" => "1.0"}

      assert RuntimeContract.missing_vars(:weather, getenv(values)) ==
               ~w(WEATHER_LON)
    end

    test "spotify required vars" do
      assert RuntimeContract.missing_vars(:spotify, getenv(%{})) ==
               ~w(SPOTIFY_CLIENT_ID SPOTIFY_CLIENT_SECRET SPOTIFY_REFRESH_TOKEN)
    end

    test "feed required vars" do
      assert RuntimeContract.missing_vars(:feed, getenv(%{})) ==
               ~w(PAPER_WEIGHT_FEED_HANDLES PAPER_WEIGHT_FEED_LIST_ID PAPER_WEIGHT_FEED_API_TOKEN)
    end
  end
end
