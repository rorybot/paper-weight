defmodule PaperWeight.Weather.TimelineTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Weather.Timeline

  # Build a 15-minute grid from -12h to +24h around an anchor, as Open-Meteo
  # would return with past_minutely_15=48 / forecast_minutely_15=96.
  defp grid15(anchor, back_hours \\ 12, fwd_hours \\ 24) do
    start = NaiveDateTime.add(anchor, -back_hours * 3600)
    stop = NaiveDateTime.add(anchor, fwd_hours * 3600)

    Stream.iterate(start, &NaiveDateTime.add(&1, 15 * 60))
    |> Enum.take_while(&(NaiveDateTime.compare(&1, stop) != :gt))
    |> Enum.map(&fmt/1)
  end

  defp fmt(ndt), do: ndt |> NaiveDateTime.truncate(:second) |> NaiveDateTime.to_iso8601() |> String.slice(0, 16)

  defp minutely(times) do
    n = length(times)

    %{
      "time" => times,
      "temperature_2m" => Enum.map(0..(n - 1), &(70 + rem(&1, 20) / 1.0)),
      "wind_speed_10m" => Enum.map(0..(n - 1), &(5 + rem(&1, 10) / 1.0)),
      "precipitation" => List.duplicate(0.0, n)
    }
  end

  test "full window yields 73 half-hourly points with now_index at 24" do
    anchor = ~N[2026-07-16 14:00:00]
    times = grid15(anchor)
    tl = Timeline.build(minutely(times), "2026-07-16T14:00")

    assert tl.step_minutes == 30
    # -12h..+24h = 36h span → 73 points at 30-min spacing (both ends inclusive)
    assert length(tl.series) == 73
    assert tl.now_index == 24
    assert Enum.at(tl.series, tl.now_index).time_local == "2026-07-16T14:00"

    # every retained sample lands on the :00 / :30 grid
    assert Enum.all?(tl.series, fn %{time_local: t} ->
             String.ends_with?(t, ":00") or String.ends_with?(t, ":30")
           end)

    first = hd(tl.series)
    assert is_number(first.temp_f)
    assert is_number(first.wind_mph)
    assert is_number(first.precip_in)
  end

  test "partial past shifts now_index to match available data" do
    anchor = ~N[2026-07-16 14:00:00]
    # only 3h of history available (data gap) → now sits 6 half-hours in
    times = grid15(anchor, 3, 24)
    tl = Timeline.build(minutely(times), "2026-07-16T14:00")

    assert tl.now_index == 6
    assert Enum.at(tl.series, tl.now_index).time_local == "2026-07-16T14:00"
    assert length(tl.series) == 55
  end

  test "missing minutely_15 yields an empty but valid timeline" do
    tl = Timeline.build(nil, "2026-07-16T14:00")
    assert tl == %{step_minutes: 30, now_index: 0, series: []}
  end

  test "nil current time falls back to now_index 0" do
    times = grid15(~N[2026-07-16 14:00:00])
    tl = Timeline.build(minutely(times), nil)
    assert tl.now_index == 0
    assert length(tl.series) == 73
  end

  test "null variable values are preserved as nil, timestamps kept" do
    minutely = %{
      "time" => ["2026-07-16T14:00", "2026-07-16T14:30"],
      "temperature_2m" => [88.0, nil],
      "wind_speed_10m" => [nil, 9.0],
      "precipitation" => [0.0, nil]
    }

    tl = Timeline.build(minutely, "2026-07-16T14:00")
    assert length(tl.series) == 2
    assert Enum.at(tl.series, 0) == %{time_local: "2026-07-16T14:00", temp_f: 88.0, wind_mph: nil, precip_in: 0.0}
    assert Enum.at(tl.series, 1) == %{time_local: "2026-07-16T14:30", temp_f: nil, wind_mph: 9.0, precip_in: nil}
  end
end
