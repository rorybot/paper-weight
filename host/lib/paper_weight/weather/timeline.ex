defmodule PaperWeight.Weather.Timeline do
  @moduledoc """
  Pure builder for the half-hourly scrub timeline (W6a).

  Turns an Open-Meteo `minutely_15` block (already-decoded map, string keys)
  into a half-hourly series of temperature / wind / precipitation covering the
  −12h…+24h window, plus a `now_index` aligned to the current observation time.

  Fetch-mechanism-agnostic: the caller decides how the upstream samples are
  produced (minutely_15 today). This module only downsamples to the 30-minute
  grid and computes the "now" index, so the frozen envelope shape (below) never
  depends on the upstream cadence.

  ## Frozen envelope shape (W6a — device W6b consumes this)

      %{
        "step_minutes" => 30,
        "now_index" => non_neg_integer(),      # index into "series"; 0 when unknown
        "series" => [
          %{
            "time_local" => "YYYY-MM-DDTHH:MM", # Open-Meteo local time, no offset
            "temp_f" => number() | nil,         # temperature, °F
            "wind_mph" => number() | nil,       # wind speed, mph
            "precip_in" => number() | nil       # precipitation, inches
          },
          ...
        ]                                       # oldest → newest, 30-min spacing
      }
  """

  @step_minutes 30

  @type point :: %{
          time_local: String.t(),
          temp_f: number() | nil,
          wind_mph: number() | nil,
          precip_in: number() | nil
        }

  @type t :: %{
          step_minutes: pos_integer(),
          now_index: non_neg_integer(),
          series: [point()]
        }

  @doc """
  Build the half-hourly timeline from a `minutely_15` block and the current
  observation time (both may be missing → empty series, `now_index` 0).
  """
  @spec build(map() | nil, String.t() | nil) :: t()
  def build(minutely_15, current_time) do
    series = build_series(minutely_15)
    %{step_minutes: @step_minutes, now_index: now_index(series, current_time), series: series}
  end

  @spec step_minutes() :: pos_integer()
  def step_minutes, do: @step_minutes

  defp build_series(%{"time" => times} = block) when is_list(times) do
    temps = list(block, "temperature_2m")
    winds = list(block, "wind_speed_10m")
    precips = list(block, "precipitation")

    [times, temps, winds, precips]
    |> zip4()
    |> Enum.filter(fn {time, _t, _w, _p} -> half_hour?(time) end)
    |> Enum.map(fn {time, t, w, p} ->
      %{time_local: time, temp_f: numeric(t), wind_mph: numeric(w), precip_in: numeric(p)}
    end)
  end

  defp build_series(_), do: []

  defp list(block, key) do
    case Map.get(block, key) do
      list when is_list(list) -> list
      _ -> []
    end
  end

  # Zip four lists, padding shorter ones with nil so a missing/short variable
  # array still yields points (with nil values) aligned to the timestamps.
  defp zip4(lists) do
    max = lists |> Enum.map(&length/1) |> Enum.max()

    Enum.map(0..(max - 1)//1, fn i ->
      lists
      |> Enum.map(&Enum.at(&1, i))
      |> List.to_tuple()
    end)
  end

  # Keep only samples that land on the 30-minute grid (:00 / :30).
  defp half_hour?(time) when is_binary(time) do
    case minute_of(time) do
      m when is_integer(m) -> rem(m, @step_minutes) == 0
      _ -> false
    end
  end

  defp half_hour?(_), do: false

  defp minute_of(time) when is_binary(time) do
    case naive(time) do
      {:ok, ndt} -> ndt.minute
      _ -> :error
    end
  end

  defp now_index([], _current_time), do: 0
  defp now_index(_series, nil), do: 0

  defp now_index(series, current_time) do
    case naive(current_time) do
      {:ok, now} ->
        series
        |> Enum.with_index()
        |> Enum.reduce({0, nil}, fn {%{time_local: t}, idx}, {best_idx, best_diff} ->
          case naive(t) do
            {:ok, ndt} ->
              diff = abs(NaiveDateTime.diff(ndt, now))
              if best_diff == nil or diff < best_diff, do: {idx, diff}, else: {best_idx, best_diff}

            _ ->
              {best_idx, best_diff}
          end
        end)
        |> elem(0)

      _ ->
        0
    end
  end

  # Open-Meteo local times omit seconds ("2026-07-16T14:00"); NaiveDateTime
  # needs them, so pad before parsing.
  defp naive(<<_::binary-size(16)>> = time), do: NaiveDateTime.from_iso8601(time <> ":00")
  defp naive(time) when is_binary(time), do: NaiveDateTime.from_iso8601(time)
  defp naive(_), do: :error

  defp numeric(n) when is_number(n), do: n
  defp numeric(_), do: nil
end
