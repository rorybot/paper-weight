defmodule PaperWeight.Dither do
  @moduledoc """
  Host-side image-to-bitmap pipeline for Car Thing image slots.

  Inputs are normalized grayscale images. Results are centered cover-resized,
  Atkinson-dithered, and cached by content plus render options.
  """

  alias PaperWeight.Dither.{Atkinson, Cache}
  alias PaperWeight.Image
  alias PaperWeight.Image.Resize

  @algorithm_version 1

  @spec render(Image.t(), {pos_integer(), pos_integer()}, keyword()) :: PaperWeight.Bitmap.t()
  def render(image, size, options \\ [])

  def render(%Image{} = image, {width, height} = size, options)
      when is_integer(width) and width > 0 and is_integer(height) and height > 0 do
    threshold = Keyword.get(options, :threshold, 128)
    cache = Keyword.get(options, :cache, Cache)
    producer = fn -> image |> Resize.cover(size) |> Atkinson.dither(threshold: threshold) end

    case cache do
      false -> producer.()
      server -> Cache.fetch(server, cache_key(image, size, threshold), producer)
    end
  end

  def render(%Image{}, _size, _options),
    do: raise(ArgumentError, "target dimensions must be positive")

  @spec cache_key(Image.t(), {pos_integer(), pos_integer()}, 0..255) :: binary()
  def cache_key(%Image{} = image, size, threshold) do
    :crypto.hash(
      :sha256,
      :erlang.term_to_binary(
        {@algorithm_version, image.width, image.height, image.pixels, size, threshold}
      )
    )
  end
end
