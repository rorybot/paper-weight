defmodule PaperWeight.BitmapTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Bitmap

  test "packs rows MSB first and pads each row independently" do
    bitmap = Bitmap.from_bits(3, 2, [1, 0, 1, 0, 1, 0])

    assert bitmap.data == <<0b10100000, 0b01000000>>
    assert Bitmap.bit_at(bitmap, 0, 0) == 1
    assert Bitmap.bit_at(bitmap, 2, 1) == 0
  end

  test "exports binary and plain PBM" do
    bitmap = Bitmap.from_bits(2, 1, [1, 0])

    assert Bitmap.to_pbm(bitmap, :binary) == "P4\n2 1\n" <> <<0b10000000>>
    assert Bitmap.to_pbm(bitmap, :plain) == "P1\n2 1\n1 0\n"
  end
end
