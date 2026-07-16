defmodule PaperWeight.Weather.SnapshotTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Weather.Snapshot

  defp sample_parts(overrides \\ %{}) do
    Map.merge(
      %{
        location_label: "Castle Rock, CO",
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

    assert snap["location_label"] == "Castle Rock, CO"
    assert snap["as_of"] == "2026-07-16T20:00:00Z"
    assert snap["stale"] == false
    assert snap["current"] == %{"temp_f" => 88, "summary" => "Sunny"}
    assert is_binary(snap["walk_verdict"])
    assert snap["uv"] == %{"index" => 9.2, "grade" => "extreme"}
    assert length(snap["days5"]) == 5
    assert length(snap["days7"]) == 7
    assert hd(snap["days5"])["date"] == "2026-07-16"
    assert hd(snap["hourly_uv"]) == %{"hour_local" => "19:00", "index" => 9.2}
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
