defmodule PaperWeight.Weather.OpenMeteo do
  @moduledoc """
  Pure parser for Open-Meteo `/v1/forecast` JSON responses.

  Expects an already-decoded map (string keys). No API key required —
  `current`/`daily`/`hourly` variables are selected by the request URL
  (`PaperWeight.Weather.Config.open_meteo_url/1`).
  """

  alias PaperWeight.Weather.WeatherCode

  @type day :: %{date: String.t(), high_f: number(), low_f: number(), summary: String.t()}
  @type current :: %{temp_f: number(), summary: String.t()}
  @type hourly :: %{hour_local: String.t(), index: number()}

  @type parsed :: %{
          current: current(),
          days: [day()],
          uv_index: number(),
          hourly_uv: [hourly()]
        }

  @spec parse(map()) :: {:ok, parsed()} | {:error, term()}
  def parse(%{"current" => current, "daily" => daily} = body)
      when is_map(current) and is_map(daily) do
    with {:ok, parsed_current} <- parse_current(current),
         {:ok, days} <- parse_days(daily) do
      uv_index = numeric(current["uv_index"]) || 0.0
      hourly_uv = parse_hourly(Map.get(body, "hourly"))

      {:ok, %{current: parsed_current, days: days, uv_index: uv_index, hourly_uv: hourly_uv}}
    end
  end

  def parse(_), do: {:error, :invalid_forecast}

  defp parse_current(%{"temperature_2m" => temp} = current) when is_number(temp) do
    {:ok, %{temp_f: temp, summary: WeatherCode.summary(Map.get(current, "weather_code"))}}
  end

  defp parse_current(_), do: {:error, :invalid_current}

  defp parse_days(%{"time" => times} = daily) when is_list(times) and times != [] do
    highs = Map.get(daily, "temperature_2m_max", [])
    lows = Map.get(daily, "temperature_2m_min", [])
    codes = Map.get(daily, "weather_code", [])

    days =
      [times, highs, lows, codes]
      |> Enum.zip()
      |> Enum.map(fn {date, high, low, code} ->
        %{date: date, high_f: high, low_f: low, summary: WeatherCode.summary(code)}
      end)

    if days == [], do: {:error, :empty_days}, else: {:ok, days}
  end

  defp parse_days(_), do: {:error, :invalid_daily}

  defp numeric(n) when is_number(n), do: n * 1.0
  defp numeric(_), do: nil

  defp parse_hourly(%{"time" => times, "uv_index" => indexes})
       when is_list(times) and is_list(indexes) do
    [times, indexes]
    |> Enum.zip()
    |> Enum.filter(fn {_t, i} -> is_number(i) end)
    |> Enum.take(24)
    |> Enum.map(fn {t, i} -> %{hour_local: hour_local(t), index: i} end)
  end

  defp parse_hourly(_), do: []

  defp hour_local(iso) when is_binary(iso) do
    case String.split(iso, "T", parts: 2) do
      [_date, time] -> String.slice(time, 0, 5)
      _ -> iso
    end
  end

  defp hour_local(other), do: other
end
