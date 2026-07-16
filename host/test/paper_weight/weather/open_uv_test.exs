defmodule PaperWeight.Weather.OpenUvTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Weather.{JsonLite, OpenUv}

  @fixture_dir Path.join([__DIR__, "fixtures"])

  defp load(name) do
    assert {:ok, map} = JsonLite.decode(File.read!(Path.join(@fixture_dir, name)))
    map
  end

  test "parse_uv reads index" do
    assert {:ok, %{index: 9.2}} = OpenUv.parse_uv(load("openuv_uv.json"))
  end

  test "parse_forecast builds hourly series" do
    assert {:ok, hours} = OpenUv.parse_forecast(load("openuv_forecast.json"))
    assert length(hours) == 6
    assert hd(hours).hour_local == "13:00"
    assert hd(hours).index == 1.1
  end
end
