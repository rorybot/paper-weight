defmodule PaperWeight.Weather.Nws do
  @moduledoc """
  Pure-ish parsers for National Weather Service JSON responses.

  Expects already-decoded maps (string keys from `:json` / Jason-style).
  """

  @type day :: %{
          date: String.t(),
          high_f: number(),
          low_f: number(),
          summary: String.t()
        }

  @type current :: %{temp_f: number(), summary: String.t()}

  @type parsed :: %{
          location_label: String.t() | nil,
          forecast_url: String.t() | nil,
          current: current() | nil,
          days: [day()]
        }

  @spec parse_points(map()) :: {:ok, %{location_label: String.t() | nil, forecast_url: String.t()}} | {:error, term()}
  def parse_points(%{"properties" => props}) when is_map(props) do
    forecast = Map.get(props, "forecast")
    label = location_label_from_points(props)

    if is_binary(forecast) do
      {:ok, %{location_label: label, forecast_url: forecast}}
    else
      {:error, :missing_forecast_url}
    end
  end

  def parse_points(_), do: {:error, :invalid_points}

  @spec parse_forecast(map()) :: {:ok, %{current: current(), days: [day()]}} | {:error, term()}
  def parse_forecast(%{"properties" => %{"periods" => periods}}) when is_list(periods) do
    days = periods_to_days(periods)
    current = first_current(periods)

    if current == nil or days == [] do
      {:error, :empty_forecast}
    else
      {:ok, %{current: current, days: days}}
    end
  end

  def parse_forecast(_), do: {:error, :invalid_forecast}

  defp location_label_from_points(props) do
    case get_in(props, ["relativeLocation", "properties"]) do
      %{"city" => city, "state" => state} when is_binary(city) and is_binary(state) ->
        "#{city}, #{state}"

      _ ->
        nil
    end
  end

  defp first_current([%{"temperature" => temp, "shortForecast" => summary} | _])
       when is_number(temp) and is_binary(summary) do
    %{temp_f: temp, summary: summary}
  end

  defp first_current([_ | rest]), do: first_current(rest)
  defp first_current([]), do: nil

  defp periods_to_days(periods) do
    periods
    |> Enum.reduce(%{}, fn period, acc ->
      date = period_date(period)
      if date, do: merge_period(acc, date, period), else: acc
    end)
    |> Enum.sort_by(fn {date, _} -> date end)
    |> Enum.map(fn {_date, day} -> day end)
  end

  defp period_date(%{"startTime" => start}) when is_binary(start) do
    case String.split(start, "T", parts: 2) do
      [date, _] -> date
      _ -> nil
    end
  end

  defp period_date(_), do: nil

  defp merge_period(acc, date, period) do
    is_day? = Map.get(period, "isDaytime", true)
    temp = Map.get(period, "temperature")
    summary = Map.get(period, "shortForecast") || Map.get(period, "name") || ""

    base =
      Map.get(acc, date, %{
        date: date,
        high_f: nil,
        low_f: nil,
        summary: ""
      })

    updated =
      cond do
        is_day? and is_number(temp) ->
          %{base | high_f: temp, summary: if(base.summary == "", do: summary, else: base.summary)}

        not is_day? and is_number(temp) ->
          %{base | low_f: temp}

        true ->
          base
      end

    # If only one period, use its temp for both high and low later
    updated =
      if is_day? and updated.summary == "" and is_binary(summary) do
        %{updated | summary: summary}
      else
        updated
      end

    Map.put(acc, date, updated)
  end

  @doc """
  Finalize day rows: fill missing high/low from the other, drop incomplete.
  """
  @spec finalize_days([day() | map()]) :: [day()]
  def finalize_days(days) do
    days
    |> Enum.map(&fill_day/1)
    |> Enum.filter(fn d -> is_number(d.high_f) and is_number(d.low_f) end)
  end

  defp fill_day(%{high_f: h, low_f: nil} = d) when is_number(h), do: %{d | low_f: h}
  defp fill_day(%{high_f: nil, low_f: l} = d) when is_number(l), do: %{d | high_f: l}
  defp fill_day(d), do: d
end
