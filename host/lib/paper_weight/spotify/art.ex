defmodule PaperWeight.Spotify.Art do
  @moduledoc """
  Thin wrapper over `PaperWeight.Dither` (P5, locked — call only, never edit) to
  turn album art into `art_pbm_base64`. Downloading/decoding album art bytes is
  out of scope for N1; callers that don't have an `Image` yet should pass `nil`
  and ship `art_pbm_base64: null` (allowed by the N1 acceptance criteria).
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
end
