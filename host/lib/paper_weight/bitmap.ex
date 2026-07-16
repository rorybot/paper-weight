defmodule PaperWeight.Bitmap do
  @moduledoc """
  Row-padded, MSB-first 1-bit bitmap. A set bit represents black.
  """

  import Bitwise

  @enforce_keys [:width, :height, :data]
  defstruct [:width, :height, :data]

  @type t :: %__MODULE__{width: pos_integer(), height: pos_integer(), data: binary()}

  @spec from_bits(pos_integer(), pos_integer(), [0 | 1]) :: t()
  def from_bits(width, height, bits)
      when is_integer(width) and width > 0 and is_integer(height) and height > 0 and
             is_list(bits) do
    if length(bits) != width * height or not Enum.all?(bits, &(&1 in [0, 1])) do
      raise ArgumentError, "bitmap bits must contain exactly width * height binary values"
    end

    data =
      bits
      |> Enum.chunk_every(width)
      |> Enum.map(&pack_row/1)
      |> IO.iodata_to_binary()

    %__MODULE__{width: width, height: height, data: data}
  end

  @spec bit_at(t(), non_neg_integer(), non_neg_integer()) :: 0 | 1
  def bit_at(%__MODULE__{} = bitmap, x, y)
      when x >= 0 and x < bitmap.width and y >= 0 and y < bitmap.height do
    byte = :binary.at(bitmap.data, y * row_bytes(bitmap.width) + div(x, 8))
    byte >>> (7 - rem(x, 8)) &&& 1
  end

  @spec to_pbm(t(), :binary | :plain) :: binary()
  def to_pbm(%__MODULE__{} = bitmap, :binary) do
    "P4\n#{bitmap.width} #{bitmap.height}\n" <> bitmap.data
  end

  def to_pbm(%__MODULE__{} = bitmap, :plain) do
    rows =
      for y <- 0..(bitmap.height - 1) do
        for(x <- 0..(bitmap.width - 1), do: Integer.to_string(bit_at(bitmap, x, y)))
        |> Enum.join(" ")
      end

    "P1\n#{bitmap.width} #{bitmap.height}\n" <> Enum.join(rows, "\n") <> "\n"
  end

  defp pack_row(bits) do
    padding = List.duplicate(0, rem(8 - rem(length(bits), 8), 8))

    bits
    |> Kernel.++(padding)
    |> Enum.chunk_every(8)
    |> Enum.map(fn byte_bits -> Enum.reduce(byte_bits, 0, &(&2 <<< 1 ||| &1)) end)
  end

  defp row_bytes(width), do: div(width + 7, 8)
end
