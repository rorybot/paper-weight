defmodule PaperWeight.ImageTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Image
  alias PaperWeight.Image.Resize

  test "constructs a rectangular grayscale image" do
    assert {:ok, image} = Image.from_rows([[0, 64], [128, 255]])
    assert image.width == 2
    assert image.height == 2
    assert Image.pixel_at(image, 1, 1) == 255
  end

  test "rejects malformed pixel data" do
    assert {:error, :ragged_rows} = Image.from_rows([[0, 1], [2]])
    assert {:error, :invalid_pixel} = Image.from_rows([[0, 256]])
    assert {:error, :pixel_count_mismatch} = Image.new(2, 2, [0, 1, 2])
  end

  test "cover resize crops from the center" do
    image = Image.from_rows!([[0, 10, 20, 30], [40, 50, 60, 70]])
    resized = Resize.cover(image, {2, 2})

    assert resized == Image.from_rows!([[10, 20], [50, 60]])
  end

  test "cover resize rejects non-positive target dimensions" do
    image = Image.from_rows!([[0]])

    assert_raise ArgumentError, fn -> Resize.cover(image, {0, 1}) end
  end
end
