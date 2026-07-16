defmodule PaperWeight.Weather.Config do
  @moduledoc """
  Weather service configuration.

  Location is **not** hardcoded. Set opts or environment:

  - `WEATHER_LAT` / `WEATHER_LON` — required for live NWS/OpenUV URL build
  - `WEATHER_LOCATION_LABEL` — optional display label (default `"local"`)
  - `OPENUV_API_KEY` — OpenUV key
  - `WEATHER_USER_AGENT` — NWS requires a descriptive User-Agent

  Tests should pass explicit `nws_points_url` / OpenUV URLs or test coords.
  """

  @type t :: %{
          lat: float() | nil,
          lon: float() | nil,
          location_label: String.t(),
          refresh_ms: pos_integer(),
          user_agent: String.t(),
          openuv_api_key: String.t() | nil,
          nws_points_url: String.t() | nil,
          openuv_uv_url: String.t() | nil,
          openuv_forecast_url: String.t() | nil
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
      openuv_api_key: Keyword.get(opts, :openuv_api_key, System.get_env("OPENUV_API_KEY")),
      nws_points_url: Keyword.get(opts, :nws_points_url),
      openuv_uv_url: Keyword.get(opts, :openuv_uv_url),
      openuv_forecast_url: Keyword.get(opts, :openuv_forecast_url)
    }
  end

  @spec points_url(t()) :: String.t()
  def points_url(%{nws_points_url: url}) when is_binary(url), do: url

  def points_url(%{lat: lat, lon: lon}) when is_number(lat) and is_number(lon) do
    "https://api.weather.gov/points/#{lat},#{lon}"
  end

  def points_url(_config) do
    raise ArgumentError,
          "weather location missing: set WEATHER_LAT + WEATHER_LON or pass :nws_points_url"
  end

  @spec openuv_uv_url(t()) :: String.t()
  def openuv_uv_url(%{openuv_uv_url: url}) when is_binary(url), do: url

  def openuv_uv_url(%{lat: lat, lon: lon}) when is_number(lat) and is_number(lon) do
    "https://api.openuv.io/api/v1/uv?lat=#{lat}&lng=#{lon}"
  end

  def openuv_uv_url(_config) do
    raise ArgumentError,
          "weather location missing: set WEATHER_LAT + WEATHER_LON or pass :openuv_uv_url"
  end

  @spec openuv_forecast_url(t()) :: String.t()
  def openuv_forecast_url(%{openuv_forecast_url: url}) when is_binary(url), do: url

  def openuv_forecast_url(%{lat: lat, lon: lon}) when is_number(lat) and is_number(lon) do
    "https://api.openuv.io/api/v1/forecast?lat=#{lat}&lng=#{lon}"
  end

  def openuv_forecast_url(_config) do
    raise ArgumentError,
          "weather location missing: set WEATHER_LAT + WEATHER_LON or pass :openuv_forecast_url"
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
