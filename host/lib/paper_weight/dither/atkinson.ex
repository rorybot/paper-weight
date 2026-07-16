defmodule PaperWeight.Dither.Atkinson do
  @moduledoc """
  Pure Atkinson error diffusion over an 8-bit grayscale image.

  Six neighbours each receive one eighth of the quantization error; the
  remaining quarter is intentionally discarded, giving Atkinson its crisp
  printed character.
  """

  alias PaperWeight.{Bitmap, Image}

  @default_threshold 128

  @spec dither(Image.t(), keyword()) :: Bitmap.t()
  def dither(%Image{} = image, options \\ []) do
    threshold = Keyword.get(options, :threshold, @default_threshold)

    unless is_integer(threshold) and threshold >= 0 and threshold <= 255 do
      raise ArgumentError, "threshold must be an integer from 0 through 255"
    end

    buffer =
      image.pixels
      |> Tuple.to_list()
      |> Enum.map(&(&1 * 1.0))
      |> :array.from_list()

    bits =
      diffuse(0, image.width * image.height, image.width, image.height, buffer, threshold, [])

    Bitmap.from_bits(image.width, image.height, Enum.reverse(bits))
  end

  defp diffuse(index, total, _width, _height, _buffer, _threshold, bits)
       when index == total,
       do: bits

  defp diffuse(index, total, width, height, buffer, threshold, bits) do
    x = rem(index, width)
    y = div(index, width)
    old_value = index |> :array.get(buffer) |> clamp()
    new_value = if old_value < threshold, do: 0.0, else: 255.0
    bit = if new_value == 0.0, do: 1, else: 0
    error_share = (old_value - new_value) / 8.0

    next_buffer =
      neighbours(x, y, width, height)
      |> Enum.reduce(buffer, fn neighbour, values ->
        :array.set(neighbour, :array.get(neighbour, values) + error_share, values)
      end)

    diffuse(index + 1, total, width, height, next_buffer, threshold, [bit | bits])
  end

  defp neighbours(x, y, width, height) do
    [{x + 1, y}, {x + 2, y}, {x - 1, y + 1}, {x, y + 1}, {x + 1, y + 1}, {x, y + 2}]
    |> Enum.filter(fn {next_x, next_y} ->
      next_x >= 0 and next_x < width and next_y >= 0 and next_y < height
    end)
    |> Enum.map(fn {next_x, next_y} -> next_y * width + next_x end)
  end

  defp clamp(value), do: value |> max(0.0) |> min(255.0)
end
