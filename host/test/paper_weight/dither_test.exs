defmodule PaperWeight.DitherTest do
  use ExUnit.Case, async: true

  alias PaperWeight.{Bitmap, Dither, Image}
  alias PaperWeight.Dither.{Atkinson, Cache}

  @golden_path Path.expand("../fixtures/atkinson-gradient-8x8.pbm", __DIR__)

  test "matches the Atkinson gradient golden image" do
    row = [0, 36, 73, 109, 146, 182, 219, 255]
    image = Image.from_rows!(List.duplicate(row, 8))
    actual = image |> Atkinson.dither() |> Bitmap.to_pbm(:plain)

    assert actual == File.read!(@golden_path)
  end

  test "produces only black and white output at source size" do
    image = Image.from_rows!([[0, 255], [255, 0]])
    bitmap = Atkinson.dither(image)

    assert bitmap.width == 2
    assert bitmap.height == 2
    assert for(y <- 0..1, x <- 0..1, do: Bitmap.bit_at(bitmap, x, y)) == [1, 0, 0, 1]
  end

  test "validates the threshold" do
    image = Image.from_rows!([[128]])

    assert_raise ArgumentError, fn -> Atkinson.dither(image, threshold: 256) end
  end

  test "resizes, dithers, and caches by content and render options" do
    cache = start_supervised!({Cache, []})
    image = Image.from_rows!([[0, 64], [192, 255]])

    first = Dither.render(image, {4, 4}, cache: cache)
    second = Dither.render(image, {4, 4}, cache: cache)

    assert first == second
    assert first.width == 4
    assert first.height == 4
    assert Cache.stats(cache) == %{entries: 1, hits: 1, misses: 1}

    Dither.render(image, {4, 4}, cache: cache, threshold: 96)
    assert Cache.stats(cache) == %{entries: 2, hits: 1, misses: 2}
  end

  test "can bypass the cache" do
    image = Image.from_rows!([[0, 255]])

    assert %Bitmap{} = Dither.render(image, {2, 1}, cache: false)
  end
end
