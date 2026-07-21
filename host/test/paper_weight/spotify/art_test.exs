defmodule PaperWeight.Spotify.ArtTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Image
  alias PaperWeight.Spotify.Art

  @fixture_dir Path.join([__DIR__, "fixtures"])

  defp fixture(name), do: File.read!(Path.join(@fixture_dir, name))

  test "dither_to_base64 returns nil when no image is available (default N1 path)" do
    assert Art.dither_to_base64(nil, {8, 8}) == nil
  end

  test "dither_to_base64 dithers a tiny fixture image via PaperWeight.Dither and base64-encodes it" do
    image = Image.new!(2, 2, [0, 255, 255, 0])

    result = Art.dither_to_base64(image, {2, 2}, cache: false)

    assert is_binary(result)
    assert {:ok, _pbm_bytes} = Base.decode64(result)
  end

  test "decode turns downloaded album art bytes into a grayscale Image" do
    bytes = fixture("album_art.jpg")

    assert {:ok, %Image{width: 4, height: 4} = image} = Art.decode(bytes)
    assert tuple_size(image.pixels) == 16
    assert Enum.all?(Tuple.to_list(image.pixels), &(&1 in 0..255))
  end

  test "decode returns an error tuple for malformed bytes instead of raising" do
    assert {:error, _reason} = Art.decode("not an image")
  end

  test "decode result can be dithered end to end" do
    {:ok, image} = Art.decode(fixture("album_art.jpg"))

    result = Art.dither_to_base64(image, {8, 8}, cache: false)

    assert is_binary(result)
    assert {:ok, _pbm_bytes} = Base.decode64(result)
  end
end
