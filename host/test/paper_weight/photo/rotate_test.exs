defmodule PaperWeight.Photo.RotateTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Photo.Rotate

  @interval 5
  @t0 1_000_000

  defp photos do
    [
      %{id: "a", path: "/a.jpg", caption: "A"},
      %{id: "b", path: "/b.jpg", caption: "B"},
      %{id: "c", path: "/c.jpg", caption: "C"}
    ]
  end

  defp state(opts \\ []) do
    photos = Keyword.get(opts, :photos, photos())
    now = Keyword.get(opts, :now, @t0)
    Rotate.new(photos, @interval, now)
  end

  test "starts at first photo with full interval countdown" do
    s = state()
    assert Rotate.display_index(s) == 1
    assert Rotate.total(s) == 3
    assert Rotate.current(s).id == "a"
    assert Rotate.reprints_in_min(s, @t0) == 5
    assert s.kept == false
  end

  test "skip advances, wraps, clears keep, resets timer" do
    s =
      state()
      |> Rotate.keep()
      |> Rotate.skip(@t0 + 90_000)

    assert s.kept == false
    assert Rotate.current(s).id == "b"
    assert Rotate.display_index(s) == 2
    assert Rotate.reprints_in_min(s, @t0 + 90_000) == 5

    s = Rotate.skip(s, @t0 + 90_000)
    s = Rotate.skip(s, @t0 + 90_000)
    assert Rotate.current(s).id == "a"
    assert Rotate.display_index(s) == 1
  end

  test "keep toggles pin; tick does not advance while kept even when due" do
    s = state() |> Rotate.keep()
    assert s.kept == true

    due = @t0 + @interval * 60_000
    s2 = Rotate.tick(s, due)
    assert s2 == s
    assert Rotate.current(s2).id == "a"

    s3 = Rotate.keep(s2)
    assert s3.kept == false
    s4 = Rotate.tick(s3, due)
    assert Rotate.current(s4).id == "b"
    assert s4.kept == false
    assert Rotate.reprints_in_min(s4, due) == 5
  end

  test "tick advances when due and not kept" do
    s = state()
    almost = @t0 + @interval * 60_000 - 1
    assert Rotate.tick(s, almost) == s

    due = @t0 + @interval * 60_000
    s2 = Rotate.tick(s, due)
    assert Rotate.current(s2).id == "b"
    assert Rotate.display_index(s2) == 2
  end

  test "reprints_in_min ceils remaining minutes" do
    s = state()
    # 4 min + 1 ms remaining → still 5? Wait: interval is 5 min from t0
    # at t0 + 1ms: remaining = 5*60_000 - 1 → ceil minutes = 5
    assert Rotate.reprints_in_min(s, @t0 + 1) == 5
    # exactly 4 min remaining
    assert Rotate.reprints_in_min(s, @t0 + 60_000) == 4
    # 1 ms into last minute → 1
    assert Rotate.reprints_in_min(s, @t0 + 4 * 60_000 + 1) == 1
    assert Rotate.reprints_in_min(s, @t0 + 5 * 60_000) == 0
  end

  test "N/M correct across skip and keep sequence" do
    s = state()
    assert {1, 3} = {Rotate.display_index(s), Rotate.total(s)}

    s = Rotate.skip(s, @t0)
    assert {2, 3} = {Rotate.display_index(s), Rotate.total(s)}

    s = Rotate.keep(s)
    assert s.kept
    assert {2, 3} = {Rotate.display_index(s), Rotate.total(s)}

    s = Rotate.skip(s, @t0 + 1_000)
    assert s.kept == false
    assert {3, 3} = {Rotate.display_index(s), Rotate.total(s)}
  end

  test "rescan keeps current id when still present" do
    s = state() |> Rotate.skip(@t0)
    assert Rotate.current(s).id == "b"

    new_photos = [
      %{id: "b", path: "/b2.jpg", caption: "B2"},
      %{id: "z", path: "/z.jpg", caption: "Z"}
    ]

    s2 = Rotate.rescan(s, new_photos, @t0 + 10)
    assert Rotate.current(s2).id == "b"
    assert Rotate.current(s2).caption == "B2"
    assert Rotate.total(s2) == 2
    assert s2.kept == false
    assert Rotate.reprints_in_min(s2, @t0 + 10) == 5
  end

  test "empty library is a no-op for skip/keep/tick" do
    s = Rotate.new([], @interval, @t0)
    assert Rotate.display_index(s) == 0
    assert Rotate.total(s) == 0
    assert Rotate.current(s) == nil
    assert Rotate.skip(s, @t0) == s
    assert Rotate.keep(s) == s
    assert Rotate.tick(s, @t0 + 999_999) == s
  end
end
