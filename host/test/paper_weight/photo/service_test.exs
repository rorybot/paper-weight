defmodule PaperWeight.Photo.ServiceTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Photo.Service

  setup do
    dir =
      Path.join(
        System.tmp_dir!(),
        "paper-weight-photo-svc-" <> Integer.to_string(System.unique_integer([:positive]))
      )

    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "a.jpg"), "a")
    File.write!(Path.join(dir, "b.jpg"), "b")
    File.write!(Path.join(dir, "c.jpg"), "c")
    File.write!(Path.join(dir, "a.txt"), "First print")

    on_exit(fn -> File.rm_rf!(dir) end)

    clock = :atomics.new(1, signed: false)
    :atomics.put(clock, 1, 1_000_000)

    now_ms_fn = fn -> :atomics.get(clock, 1) end

    advance = fn ms ->
      :atomics.add(clock, 1, ms)
      :atomics.get(clock, 1)
    end

    %{dir: dir, now_ms_fn: now_ms_fn, advance: advance, clock: clock}
  end

  defp start_service(dir, now_ms_fn, opts \\ []) do
    defaults = [
      auto_tick: false,
      tick_ms: :infinity,
      library_dir: dir,
      reprint_interval_min: 5,
      now_ms_fn: now_ms_fn
    ]

    start_supervised!({Service, Keyword.merge(defaults, opts)})
  end

  test "initial snapshot is photo 1/3 with full countdown", %{dir: dir, now_ms_fn: now_ms_fn} do
    pid = start_service(dir, now_ms_fn)
    assert {:ok, snap} = Service.get_snapshot(pid)

    assert snap["index"] == 1
    assert snap["total"] == 3
    assert snap["caption"] == "First print"
    assert snap["id"] == "a"
    assert snap["kept"] == false
    assert snap["reprints_in_min"] == 5
    assert snap["empty"] == false
    assert Service.get_gen(pid) == 1
  end

  test "skip and keep update N/M and countdown", %{
    dir: dir,
    now_ms_fn: now_ms_fn,
    advance: advance
  } do
    pid = start_service(dir, now_ms_fn)

    assert {:ok, s1} = Service.skip(pid)
    assert s1["index"] == 2
    assert s1["id"] == "b"
    assert s1["kept"] == false
    assert s1["reprints_in_min"] == 5

    advance.(120_000)
    assert {:ok, s2} = Service.get_snapshot(pid)
    assert s2["reprints_in_min"] == 3

    assert {:ok, kept} = Service.keep(pid)
    assert kept["kept"] == true
    assert kept["index"] == 2

    # past deadline while kept — service tick would not advance; pure check via skip path
    advance.(5 * 60_000)
    assert {:ok, still} = Service.get_snapshot(pid)
    assert still["kept"] == true
    assert still["id"] == "b"
    assert still["reprints_in_min"] == 0

    assert {:ok, after_skip} = Service.skip(pid)
    assert after_skip["kept"] == false
    assert after_skip["id"] == "c"
    assert after_skip["index"] == 3
    assert after_skip["reprints_in_min"] == 5
  end

  test "auto tick advances when due and not kept", %{
    dir: dir,
    now_ms_fn: now_ms_fn,
    advance: advance
  } do
    pid =
      start_service(dir, now_ms_fn,
        auto_tick: true,
        tick_ms: 20
      )

    assert {:ok, %{ "id" => "a"}} = Service.get_snapshot(pid)

    advance.(5 * 60_000)
    # wait for at least one scheduled tick
    Process.sleep(80)

    assert {:ok, snap} = Service.get_snapshot(pid)
    assert snap["id"] == "b"
    assert snap["index"] == 2
  end

  test "keep blocks auto tick advance", %{dir: dir, now_ms_fn: now_ms_fn, advance: advance} do
    pid =
      start_service(dir, now_ms_fn,
        auto_tick: true,
        tick_ms: 20
      )

    assert {:ok, _} = Service.keep(pid)
    advance.(5 * 60_000)
    Process.sleep(80)

    assert {:ok, snap} = Service.get_snapshot(pid)
    assert snap["id"] == "a"
    assert snap["kept"] == true
  end

  test "rescan picks up new files", %{dir: dir, now_ms_fn: now_ms_fn} do
    pid = start_service(dir, now_ms_fn)
    File.write!(Path.join(dir, "d.jpg"), "d")

    assert {:ok, snap} = Service.rescan(pid)
    assert snap["total"] == 4
    assert snap["id"] == "a"
  end
end
