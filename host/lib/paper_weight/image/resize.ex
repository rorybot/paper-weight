defmodule PaperWeight.Image.Resize do
  @moduledoc """
  Pure centered cover-resize for normalized grayscale images.

  Bilinear sampling keeps the result deterministic and avoids coupling P5 to a
  platform image library.
  """

  alias PaperWeight.Image

  @spec cover(Image.t(), {pos_integer(), pos_integer()}) :: Image.t()
  def cover(%Image{} = image, {target_width, target_height})
      when is_integer(target_width) and target_width > 0 and is_integer(target_height) and
             target_height > 0 do
    scale = max(target_width / image.width, target_height / image.height)
    visible_width = target_width / scale
    visible_height = target_height / scale
    left = (image.width - visible_width) / 2
    top = (image.height - visible_height) / 2

    pixels =
      for y <- 0..(target_height - 1), x <- 0..(target_width - 1) do
        source_x = left + (x + 0.5) / scale - 0.5
        source_y = top + (y + 0.5) / scale - 0.5
        sample(image, source_x, source_y)
      end

    Image.new!(target_width, target_height, pixels)
  end

  def cover(%Image{}, _size), do: raise(ArgumentError, "target dimensions must be positive")

  defp sample(%Image{} = image, x, y) do
    bounded_x = clamp(x, 0.0, image.width - 1.0)
    bounded_y = clamp(y, 0.0, image.height - 1.0)
    x0 = floor(bounded_x)
    y0 = floor(bounded_y)
    x1 = min(x0 + 1, image.width - 1)
    y1 = min(y0 + 1, image.height - 1)
    x_weight = bounded_x - x0
    y_weight = bounded_y - y0

    top = interpolate(Image.pixel_at(image, x0, y0), Image.pixel_at(image, x1, y0), x_weight)

    bottom =
      interpolate(Image.pixel_at(image, x0, y1), Image.pixel_at(image, x1, y1), x_weight)

    round(interpolate(top, bottom, y_weight))
  end

  defp interpolate(left, right, weight), do: left * (1.0 - weight) + right * weight
  defp clamp(value, minimum, maximum), do: value |> max(minimum) |> min(maximum)
end
