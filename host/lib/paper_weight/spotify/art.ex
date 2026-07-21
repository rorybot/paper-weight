defmodule PaperWeight.Spotify.Art do
  @moduledoc """
  Decodes downloaded album art bytes and wraps `PaperWeight.Dither` (P5, locked —
  call only, never edit) to turn them into `art_pbm_base64`.
  """

  alias PaperWeight.Bitmap
  alias PaperWeight.Dither
  alias PaperWeight.Image

  @spec dither_to_base64(Image.t() | nil, {pos_integer(), pos_integer()}, keyword()) ::
          String.t() | nil
  def dither_to_base64(image, size, options \\ [])

  def dither_to_base64(nil, _size, _options), do: nil

  def dither_to_base64(%Image{} = image, size, options) do
    image
    |> Dither.render(size, options)
    |> Bitmap.to_pbm(:binary)
    |> Base.encode64()
  end

  @doc """
  Decode JPEG/PNG bytes (as fetched from Spotify's CDN) into a grayscale `Image`.

  Returns `{:error, _}` on malformed/undecodable bytes — callers should treat
  that the same as "no art yet" and ship `art_pbm_base64: null` rather than
  failing the whole snapshot.
  """
  @spec decode(binary()) :: {:ok, Image.t()} | {:error, term()}
  def decode(bytes) when is_binary(bytes) do
    case StbImage.read_binary(bytes) do
      {:ok, stb_image} -> {:ok, to_grayscale(stb_image)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp to_grayscale(%StbImage{data: data, shape: {_height, width, channels}}) do
    pixels =
      data
      |> :binary.bin_to_list()
      |> Enum.chunk_every(channels)
      |> Enum.map(&luma/1)

    Image.new!(width, div(length(pixels), width), pixels)
  end

  defp luma([r, g, b | _rest]), do: round(0.299 * r + 0.587 * g + 0.114 * b)
  defp luma([gray]), do: gray
end
