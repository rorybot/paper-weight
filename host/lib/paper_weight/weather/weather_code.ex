defmodule PaperWeight.Weather.WeatherCode do
  @moduledoc """
  Pure WMO weather-code → short summary text, per Open-Meteo's `weather_code` field.
  """

  @spec summary(number() | nil) :: String.t()
  def summary(code) when is_number(code), do: table(trunc(code))
  def summary(_), do: "Unknown"

  defp table(0), do: "Clear"
  defp table(1), do: "Mostly Clear"
  defp table(2), do: "Partly Cloudy"
  defp table(3), do: "Overcast"
  defp table(45), do: "Fog"
  defp table(48), do: "Rime Fog"
  defp table(51), do: "Light Drizzle"
  defp table(53), do: "Drizzle"
  defp table(55), do: "Heavy Drizzle"
  defp table(56), do: "Light Freezing Drizzle"
  defp table(57), do: "Freezing Drizzle"
  defp table(61), do: "Light Rain"
  defp table(63), do: "Rain"
  defp table(65), do: "Heavy Rain"
  defp table(66), do: "Light Freezing Rain"
  defp table(67), do: "Freezing Rain"
  defp table(71), do: "Light Snow"
  defp table(73), do: "Snow"
  defp table(75), do: "Heavy Snow"
  defp table(77), do: "Snow Grains"
  defp table(80), do: "Light Showers"
  defp table(81), do: "Showers"
  defp table(82), do: "Heavy Showers"
  defp table(85), do: "Light Snow Showers"
  defp table(86), do: "Heavy Snow Showers"
  defp table(95), do: "Thunderstorm"
  defp table(96), do: "Thunderstorm w/ Hail"
  defp table(99), do: "Severe Thunderstorm"
  defp table(_), do: "Unknown"
end
