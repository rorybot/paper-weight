defmodule PaperWeight.Weather.ServiceTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Weather.Service

  @fixture_dir Path.join([__DIR__, "fixtures"])

  defp fixture(name), do: File.read!(Path.join(@fixture_dir, name))

  defp good_http do
    fn url, _headers ->
      cond do
        # gridpoints before /points/ — substring "points" matches both.
        String.contains?(url, "gridpoints") -> {:ok, fixture("nws_forecast.json")}
        String.contains?(url, "/points/") -> {:ok, fixture("nws_points.json")}
        String.contains?(url, "openuv") and String.contains?(url, "/uv") ->
          {:ok, fixture("openuv_uv.json")}

        String.contains?(url, "openuv") and String.contains?(url, "forecast") ->
          {:ok, fixture("openuv_forecast.json")}

        true ->
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
         openuv_api_key: "test-key",
         nws_points_url: "https://api.weather.gov/points/0,0",
         openuv_uv_url: "https://api.openuv.io/api/v1/uv?lat=1&lng=2",
         openuv_forecast_url: "https://api.openuv.io/api/v1/forecast?lat=1&lng=2"
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
      GenServer.start_link(Service, [
        http_get: good_http(),
        auto_refresh: false,
        refresh_ms: :infinity,
        openuv_api_key: "test-key",
        nws_points_url: "https://api.weather.gov/points/0,0",
        openuv_uv_url: "https://api.openuv.io/api/v1/uv?lat=1&lng=2",
        openuv_forecast_url: "https://api.openuv.io/api/v1/forecast?lat=1&lng=2"
      ])

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
