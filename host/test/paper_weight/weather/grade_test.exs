defmodule PaperWeight.Weather.GradeTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Weather.Grade

  test "low when index < 6" do
    assert Grade.grade_uv(0) == :low
    assert Grade.grade_uv(5.9) == :low
    assert Grade.grade_uv(5) == :low
  end

  test "high when 6 <= index < 8" do
    assert Grade.grade_uv(6) == :high
    assert Grade.grade_uv(7.9) == :high
    assert Grade.grade_uv(7) == :high
  end

  test "extreme when index >= 8" do
    assert Grade.grade_uv(8) == :extreme
    assert Grade.grade_uv(11) == :extreme
    assert Grade.grade_uv(9.2) == :extreme
  end

  test "to_string protocol forms" do
    assert Grade.to_string(:extreme) == "extreme"
    assert Grade.to_string(:high) == "high"
    assert Grade.to_string(:low) == "low"
  end
end
