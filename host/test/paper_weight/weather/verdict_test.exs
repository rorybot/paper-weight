defmodule PaperWeight.Weather.VerdictTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Weather.Verdict

  test "cold + precip" do
    line = Verdict.walk_verdict(%{temp_f: 35, uv_index: 1, precip: true})
    assert line == "Bundle up — cold and wet out there."
  end

  test "rain without cold" do
    line = Verdict.walk_verdict(%{temp_f: 60, uv_index: 2, summary: "Rain Showers"})
    assert line == "Take a jacket; rain's in the mix."
  end

  test "extreme UV and hot" do
    line = Verdict.walk_verdict(%{temp_f: 88, uv_index: 9.2})
    assert line == "Scorching sun — short walk, cover up."
  end

  test "extreme UV milder temp" do
    line = Verdict.walk_verdict(%{temp_f: 70, uv_index: 8})
    assert line == "UV is brutal; shade or skip the long walk."
  end

  test "high UV and warm" do
    line = Verdict.walk_verdict(%{temp_f: 78, uv_index: 7})
    assert line == "Hot and bright — keep the walk short."
  end

  test "high UV cooler" do
    line = Verdict.walk_verdict(%{temp_f: 65, uv_index: 6})
    assert line == "UV is high; hat and sunscreen if you're out."
  end

  test "very hot low UV" do
    line = Verdict.walk_verdict(%{temp_f: 95, uv_index: 3})
    assert line == "Too hot for a long walk — stick to shade."
  end

  test "freezing" do
    line = Verdict.walk_verdict(%{temp_f: 20, uv_index: 1})
    assert line == "Freezing out — walk if you must, dress warm."
  end

  test "chilly" do
    line = Verdict.walk_verdict(%{temp_f: 40, uv_index: 2})
    assert line == "Chilly; a short walk is fine with a coat."
  end

  test "pleasant default" do
    line = Verdict.walk_verdict(%{temp_f: 72, uv_index: 4})
    assert line == "Nice window for a walk."
  end

  test "deterministic for same inputs" do
    inputs = %{temp_f: 72, uv_index: 4}
    assert Verdict.walk_verdict(inputs) == Verdict.walk_verdict(inputs)
  end
end
