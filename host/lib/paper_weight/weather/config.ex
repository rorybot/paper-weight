defmodule PaperWeight.Weather.Config do
  @moduledoc """
  Weather service configuration.

  Defaults target Castle Rock / Denver metro. NWS requires a descriptive
  User-Agent. OpenUV API key is read from opts or `OPENUV_API_KEY`.
  """

  @type t :: %{
          lat: float(),
          lon: float(),
          location_label: String.t(),
          refresh_ms: pos_integer(),
          user_agent: String.t(),
          openuv_api_key: String.t() | nil,
          nws_points_url: String.t() | nil,
          openuv_uv_url: String.t() | nil,
          openuv_forecast_url: String.t() | nil
        }

  @default_lat 39.3722
  @default_lon -104.8561
  @default_label "Castle Rock, CO"
  @default_refresh_ms 15 * 60 * 1000
  @default_ua "paper-weight/0.1 (Car Thing weather; github.com/rorybot/paper-weight)"

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %{
      lat: Keyword.get(opts, :lat, @default_lat),
      lon: Keyword.get(opts, :lon, @default_lon),
      location_label: Keyword.get(opts, :location_label, @default_label),
      refresh_ms: Keyword.get(opts, :refresh_ms, @default_refresh_ms),
      user_agent: Keyword.get(opts, :user_agent, @default_ua),
      openuv_api_key: Keyword.get(opts, :openuv_api_key, System.get_env("OPENUV_API_KEY")),
      nws_points_url: Keyword.get(opts, :nws_points_url),
      openuv_uv_url: Keyword.get(opts, :openuv_uv_url),
      openuv_forecast_url: Keyword.get(opts, :openuv_forecast_url)
    }
  end

  @spec points_url(t()) :: String.t()
  def points_url(%{nws_points_url: url}) when is_binary(url), do: url

  def points_url(%{lat: lat, lon: lon}) do
    "https://api.weather.gov/points/#{lat},#{lon}"
  end

  @spec openuv_uv_url(t()) :: String.t()
  def openuv_uv_url(%{openuv_uv_url: url}) when is_binary(url), do: url

  def openuv_uv_url(%{lat: lat, lon: lon}) do
    "https://api.openuv.io/api/v1/uv?lat=#{lat}&lng=#{lon}"
  end

  @spec openuv_forecast_url(t()) :: String.t()
  def openuv_forecast_url(%{openuv_forecast_url: url}) when is_binary(url), do: url

  def openuv_forecast_url(%{lat: lat, lon: lon}) do
    "https://api.openuv.io/api/v1/forecast?lat=#{lat}&lng=#{lon}"
  end
end
