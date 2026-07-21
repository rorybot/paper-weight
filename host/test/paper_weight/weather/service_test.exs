defmodule PaperWeight.Weather.ServiceTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Weather.Service

  @fixture_dir Path.join([__DIR__, "fixtures"])

  defp fixture(name), do: File.read!(Path.join(@fixture_dir, name))

  defp good_http(name \\ "open_meteo_forecast.json") do
    fn url, _headers ->
      if String.contains?(url, "api.open-meteo.com") do
        {:ok, fixture(name)}
      else
        {:error, {:unexpected_url, url}}
      end
    end
  end

  defp failing_http do
    fn _url, _headers -> {:error, :econnrefused} end
  end

  defp start_service(http_get) do
    start_supervised!(
      {Service,
       [
         http_get: http_get,
         auto_refresh: false,
         refresh_ms: :infinity,
         location_label: "Exampleville, EX",
         open_meteo_url: "https://api.open-meteo.com/v1/forecast?latitude=0&longitude=0"
       ]}
    )
  end

  test "initial refresh populates snapshot" do
    pid = start_service(good_http())
    assert {:ok, snap} = Service.get_snapshot(pid)
    assert snap["stale"] == false
    assert snap["location_label"] == "Exampleville, EX"
    assert Service.get_gen(pid) == 1
  end

  test "failure after success keeps last good with stale: true" do
    {:ok, pid} =
      GenServer.start_link(Service,
        http_get: good_http(),
        auto_refresh: false,
        refresh_ms: :infinity,
        location_label: "Exampleville, EX",
        open_meteo_url: "https://api.open-meteo.com/v1/forecast?latitude=0&longitude=0"
      )

    assert {:ok, fresh} = Service.get_snapshot(pid)
    assert fresh["stale"] == false
    gen_before = Service.get_gen(pid)

    # Swap client to failing and refresh
    :sys.replace_state(pid, fn state -> %{state | http_get: failing_http()} end)
    assert {:ok, stale_snap} = Service.refresh_now(pid)

    assert stale_snap["stale"] == true
    assert stale_snap["location_label"] == fresh["location_label"]
    assert stale_snap["current"] == fresh["current"]
    # gen only bumps on success
    assert Service.get_gen(pid) == gen_before

    GenServer.stop(pid)
  end

  test "fetch failure leaves the prior timeline intact on the stale snapshot" do
    {:ok, pid} =
      GenServer.start_link(Service,
        http_get: good_http("open_meteo_timeline.json"),
        auto_refresh: false,
        refresh_ms: :infinity,
        location_label: "Exampleville, EX",
        open_meteo_url: "https://api.open-meteo.com/v1/forecast?latitude=0&longitude=0"
      )

    assert {:ok, fresh} = Service.get_snapshot(pid)
    assert fresh["stale"] == false
    assert length(fresh["timeline"]["series"]) == 73
    assert fresh["timeline"]["now_index"] == 24

    :sys.replace_state(pid, fn state -> %{state | http_get: failing_http()} end)
    assert {:ok, stale_snap} = Service.refresh_now(pid)

    assert stale_snap["stale"] == true
    # timeline preserved verbatim from the last good snapshot
    assert stale_snap["timeline"] == fresh["timeline"]

    GenServer.stop(pid)
  end

  test "no snapshot when first fetch fails" do
    pid = start_service(failing_http())
    assert {:error, :no_snapshot} = Service.get_snapshot(pid)
    assert Service.get_gen(pid) == 0
  end

  test "recovers after a later success following a failure" do
    pid = start_service(good_http())

    assert {:ok, fresh} = Service.get_snapshot(pid)
    assert fresh["stale"] == false
    gen_after_first_success = Service.get_gen(pid)

    :sys.replace_state(pid, fn state -> %{state | http_get: failing_http()} end)
    assert {:ok, stale_snap} = Service.refresh_now(pid)
    assert stale_snap["stale"] == true
    assert Service.get_gen(pid) == gen_after_first_success

    :sys.replace_state(pid, fn state -> %{state | http_get: good_http()} end)
    assert {:ok, recovered} = Service.refresh_now(pid)

    assert recovered["stale"] == false
    assert Service.get_gen(pid) == gen_after_first_success + 1

    GenServer.stop(pid)
  end

  test "generation only advances on successful refreshes across a mixed sequence" do
    pid = start_service(good_http())
    assert Service.get_gen(pid) == 1

    :sys.replace_state(pid, fn state -> %{state | http_get: failing_http()} end)
    assert {:ok, _stale} = Service.refresh_now(pid)
    assert Service.get_gen(pid) == 1

    assert {:ok, _stale_again} = Service.refresh_now(pid)
    assert Service.get_gen(pid) == 1

    :sys.replace_state(pid, fn state -> %{state | http_get: good_http()} end)
    assert {:ok, snap} = Service.refresh_now(pid)
    assert snap["stale"] == false
    assert Service.get_gen(pid) == 2

    assert {:ok, snap2} = Service.refresh_now(pid)
    assert snap2["stale"] == false
    assert Service.get_gen(pid) == 3

    GenServer.stop(pid)
  end
end
