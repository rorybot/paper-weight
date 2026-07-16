defmodule PaperWeight.Photo.LibraryTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Photo.Library

  setup do
    dir =
      Path.join(
        System.tmp_dir!(),
        "paper-weight-photo-lib-" <> Integer.to_string(System.unique_integer([:positive]))
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  test "orders by basename case-insensitively and reads sidecar captions", %{dir: dir} do
    touch(dir, "zeta.jpg")
    touch(dir, "Alpha.png")
    touch(dir, "beta.JPEG")
    File.write!(Path.join(dir, "Alpha.txt"), "Morning light\nsecond line\n")
    File.write!(Path.join(dir, "notes.txt"), "ignored non-image")

    entries = Library.scan(library_dir: dir)

    assert Enum.map(entries, & &1.id) == ["Alpha", "beta", "zeta"]
    assert Enum.at(entries, 0).caption == "Morning light"
    assert Enum.at(entries, 1).caption == "beta"
    assert Enum.at(entries, 2).caption == "zeta"
    assert Enum.all?(entries, &String.ends_with?(&1.path, &1.basename))
  end

  test "humanizes basename when no sidecar", %{dir: dir} do
    touch(dir, "beach_day-01.jpg")
    [entry] = Library.scan(library_dir: dir)
    assert entry.caption == "beach day 01"
  end

  test "empty or missing dir yields []", %{dir: dir} do
    assert Library.scan(library_dir: Path.join(dir, "missing")) == []
    assert Library.scan(library_dir: nil) == []
  end

  test "ignores non-image files", %{dir: dir} do
    touch(dir, "keep.jpg")
    File.write!(Path.join(dir, "readme.md"), "x")
    File.mkdir_p!(Path.join(dir, "nested"))
    File.write!(Path.join(dir, "nested/deep.jpg"), "x")

    assert [%{id: "keep"}] = Library.scan(library_dir: dir)
  end

  defp touch(dir, name) do
    File.write!(Path.join(dir, name), "bytes")
  end
end
