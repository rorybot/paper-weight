defmodule PaperWeight.Weather.SnapshotTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Weather.Snapshot

  defp sample_parts(overrides \\ %{}) do
    Map.merge(
      %{
        location_label: "Exampleville, EX",
        as_of: "2026-07-16T20:00:00Z",
        current: %{temp_f: 88, summary: "Sunny"},
        days: [
          %{date: "2026-07-16", high_f: 88, low_f: 58, summary: "Sunny"},
          %{date: "2026-07-17", high_f: 90, low_f: 60, summary: "Mostly Sunny"},
          %{date: "2026-07-18", high_f: 85, low_f: 55, summary: "Slight Chance Showers"},
          %{date: "2026-07-19", high_f: 82, low_f: 54, summary: "Partly Sunny"},
          %{date: "2026-07-20", high_f: 84, low_f: 56, summary: "Sunny"},
          %{date: "2026-07-21", high_f: 86, low_f: 57, summary: "Mostly Sunny"},
          %{date: "2026-07-22", high_f: 87, low_f: 59, summary: "Sunny"}
        ],
        uv_index: 9.2,
        hourly_uv: [%{hour_local: "19:00", index: 9.2}],
        timeline: %{
          step_minutes: 30,
          now_index: 1,
          series: [
            %{time_local: "2026-07-16T13:30", temp_f: 86, wind_mph: 7, precip_in: 0.0},
            %{time_local: "2026-07-16T14:00", temp_f: 88, wind_mph: 8, precip_in: 0.0}
          ]
        },
        stale: false
      },
      overrides
    )
  end

  test "assemble matches WeatherSnapshotV1 field set" do
    snap = Snapshot.assemble(sample_parts())

    for key <- Snapshot.required_keys() do
      assert Map.has_key?(snap, key), "missing key #{key}"
    end

    assert snap["location_label"] == "Exampleville, EX"
    assert snap["as_of"] == "2026-07-16T20:00:00Z"
    assert snap["stale"] == false
    assert snap["current"] == %{"temp_f" => 88, "summary" => "Sunny"}
    assert is_binary(snap["walk_verdict"])
    assert snap["uv"] == %{"index" => 9.2, "grade" => "extreme"}
    assert length(snap["days5"]) == 5
    assert length(snap["days7"]) == 7
    assert hd(snap["days5"])["date"] == "2026-07-16"
    assert hd(snap["hourly_uv"]) == %{"hour_local" => "19:00", "index" => 9.2}

    assert snap["timeline"]["step_minutes"] == 30
    assert snap["timeline"]["now_index"] == 1
    assert length(snap["timeline"]["series"]) == 2

    assert Enum.at(snap["timeline"]["series"], 1) == %{
             "time_local" => "2026-07-16T14:00",
             "temp_f" => 88,
             "wind_mph" => 8,
             "precip_in" => 0.0
           }
  end

  test "assemble emits an empty valid timeline when parts omit it" do
    snap = Snapshot.assemble(sample_parts(%{timeline: nil}))
    assert snap["timeline"] == %{"step_minutes" => 30, "now_index" => 0, "series" => []}
  end

  test "days5 is first five; days7 pads if needed" do
    short_days =
      Enum.map(1..3, fn i ->
        %{date: "2026-07-1#{i}", high_f: 80 + i, low_f: 50, summary: "Sunny"}
      end)

    snap = Snapshot.assemble(sample_parts(%{days: short_days}))
    assert length(snap["days5"]) == 3
    assert length(snap["days7"]) == 7
    assert List.last(snap["days7"])["date"] == "2026-07-17"
  end

  test "mark_stale flips stale flag only" do
    snap = Snapshot.assemble(sample_parts())
    stale = Snapshot.mark_stale(snap)
    assert stale["stale"] == true
    assert stale["location_label"] == snap["location_label"]
    assert stale["uv"] == snap["uv"]
  end
end
