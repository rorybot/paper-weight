defmodule PaperWeight.Spotify.ArtTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Image
  alias PaperWeight.Spotify.Art

  test "dither_to_base64 returns nil when no image is available (default N1 path)" do
    assert Art.dither_to_base64(nil, {8, 8}) == nil
  end

  test "dither_to_base64 dithers a tiny fixture image via PaperWeight.Dither and base64-encodes it" do
    image = Image.new!(2, 2, [0, 255, 255, 0])

    result = Art.dither_to_base64(image, {2, 2}, cache: false)

    assert is_binary(result)
    assert {:ok, _pbm_bytes} = Base.decode64(result)
  end
end
