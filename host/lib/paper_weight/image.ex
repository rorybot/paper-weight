defmodule PaperWeight.Image do
  @moduledoc """
  Dependency-free grayscale image used by the host image pipeline.

  Source adapters are responsible for decoding formats such as JPEG or PNG and
  converting their pixels to 8-bit luma values before calling this module.
  """

  @enforce_keys [:width, :height, :pixels]
  defstruct [:width, :height, :pixels]

  @type pixel :: 0..255
  @type t :: %__MODULE__{
          width: pos_integer(),
          height: pos_integer(),
          pixels: tuple()
        }

  @spec new(pos_integer(), pos_integer(), [integer()]) :: {:ok, t()} | {:error, atom()}
  def new(width, height, pixels)
      when is_integer(width) and width > 0 and is_integer(height) and height > 0 and
             is_list(pixels) do
    cond do
      length(pixels) != width * height ->
        {:error, :pixel_count_mismatch}

      not Enum.all?(pixels, &valid_pixel?/1) ->
        {:error, :invalid_pixel}

      true ->
        {:ok, %__MODULE__{width: width, height: height, pixels: List.to_tuple(pixels)}}
    end
  end

  def new(_width, _height, _pixels), do: {:error, :invalid_dimensions}

  @spec new!(pos_integer(), pos_integer(), [integer()]) :: t()
  def new!(width, height, pixels) do
    case new(width, height, pixels) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, "invalid grayscale image: #{reason}"
    end
  end

  @spec from_rows([[integer()]]) :: {:ok, t()} | {:error, atom()}
  def from_rows([first | _] = rows) when is_list(first) and first != [] do
    width = length(first)

    if Enum.all?(rows, &(is_list(&1) and length(&1) == width)) do
      new(width, length(rows), List.flatten(rows))
    else
      {:error, :ragged_rows}
    end
  end

  def from_rows(_rows), do: {:error, :invalid_rows}

  @spec from_rows!([[integer()]]) :: t()
  def from_rows!(rows) do
    case from_rows(rows) do
      {:ok, image} -> image
      {:error, reason} -> raise ArgumentError, "invalid grayscale rows: #{reason}"
    end
  end

  @spec pixel_at(t(), non_neg_integer(), non_neg_integer()) :: pixel()
  def pixel_at(%__MODULE__{width: width, height: height, pixels: pixels}, x, y)
      when x >= 0 and x < width and y >= 0 and y < height do
    elem(pixels, y * width + x)
  end

  defp valid_pixel?(pixel), do: is_integer(pixel) and pixel >= 0 and pixel <= 255
end
