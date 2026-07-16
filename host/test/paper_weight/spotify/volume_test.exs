defmodule PaperWeight.Spotify.VolumeTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Spotify.Volume

  test "apply_delta increases level" do
    assert Volume.apply_delta(50, 5) == 55
  end

  test "apply_delta decreases level" do
    assert Volume.apply_delta(50, -5) == 45
  end

  test "apply_delta clamps at 0" do
    assert Volume.apply_delta(3, -100) == 0
  end

  test "apply_delta clamps at 100" do
    assert Volume.apply_delta(95, 100) == 100
  end

  test "clamp keeps in-range values unchanged" do
    assert Volume.clamp(50) == 50
  end

  test "clamp rejects negative values" do
    assert Volume.clamp(-1) == 0
  end

  test "clamp rejects values above 100" do
    assert Volume.clamp(101) == 100
  end
end
