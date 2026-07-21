defmodule PaperWeight.Weather.Config do
  @moduledoc """
  Weather service configuration.

  Location is **not** hardcoded. Set opts or environment:

  - `WEATHER_LAT` / `WEATHER_LON` — required to build the Open-Meteo forecast URL
  - `WEATHER_LOCATION_LABEL` — optional display label (default `"local"`); Open-Meteo's
    forecast endpoint does not return a place name, so this is the only source
  - `WEATHER_USER_AGENT` — descriptive User-Agent sent with the request

  No API key is required. Tests should pass an explicit `open_meteo_url` or test coords.
  """

  @type t :: %{
          lat: float() | nil,
          lon: float() | nil,
          location_label: String.t(),
          refresh_ms: pos_integer(),
          user_agent: String.t(),
          open_meteo_url: String.t() | nil
        }

  @default_refresh_ms 15 * 60 * 1000
  @default_label "local"
  @default_ua "paper-weight/0.1 (Car Thing weather; contact via repo issues)"

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %{
      lat: opt_float(opts, :lat, "WEATHER_LAT"),
      lon: opt_float(opts, :lon, "WEATHER_LON"),
      location_label:
        Keyword.get(opts, :location_label) ||
          System.get_env("WEATHER_LOCATION_LABEL") ||
          @default_label,
      refresh_ms: Keyword.get(opts, :refresh_ms, @default_refresh_ms),
      user_agent:
        Keyword.get(opts, :user_agent) ||
          System.get_env("WEATHER_USER_AGENT") ||
          @default_ua,
      open_meteo_url: Keyword.get(opts, :open_meteo_url)
    }
  end

  @spec open_meteo_url(t()) :: String.t()
  def open_meteo_url(%{open_meteo_url: url}) when is_binary(url), do: url

  def open_meteo_url(%{lat: lat, lon: lon}) when is_number(lat) and is_number(lon) do
    query =
      URI.encode_query(%{
        "latitude" => lat,
        "longitude" => lon,
        "current" => "temperature_2m,weather_code,uv_index",
        "daily" => "weather_code,temperature_2m_max,temperature_2m_min",
        "hourly" => "uv_index",
        # Half-hourly scrub timeline (W6a): sampled at 15-min, downsampled to
        # the 30-min grid host-side. 12h back (48 steps) … 24h forward (96 steps).
        "minutely_15" => "temperature_2m,wind_speed_10m,precipitation",
        "past_minutely_15" => "48",
        "forecast_minutely_15" => "96",
        "temperature_unit" => "fahrenheit",
        "wind_speed_unit" => "mph",
        "precipitation_unit" => "inch",
        "timezone" => "auto",
        "forecast_days" => "7"
      })

    "https://api.open-meteo.com/v1/forecast?#{query}"
  end

  def open_meteo_url(_config) do
    raise ArgumentError,
          "weather location missing: set WEATHER_LAT + WEATHER_LON or pass :open_meteo_url"
  end

  defp opt_float(opts, key, env_key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when is_number(value) -> value * 1.0
      {:ok, value} when is_binary(value) -> parse_float(value)
      :error -> parse_float(System.get_env(env_key))
    end
  end

  defp parse_float(nil), do: nil
  defp parse_float(""), do: nil

  defp parse_float(value) when is_binary(value) do
    case Float.parse(String.trim(value)) do
      {n, _} -> n
      :error -> nil
    end
  end
end
