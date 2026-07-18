defmodule PaperWeight.Spotify.FetchTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Spotify.{Config, Fetch}

  @fixture_dir Path.join([__DIR__, "fixtures"])

  defp fixture(name), do: File.read!(Path.join(@fixture_dir, name))

  defp config do
    Config.new(
      api_base: "https://api.spotify.test/v1",
      client_id: "cid",
      client_secret: "csecret",
      refresh_token: "rtoken"
    )
  end

  defp fresh_token(seconds_left \\ 3600) do
    %{access_token: "cached-token", expires_at: DateTime.add(DateTime.utc_now(), seconds_left, :second)}
  end

  defp expired_token do
    %{access_token: "stale-token", expires_at: DateTime.add(DateTime.utc_now(), -10, :second)}
  end

  defp counting_http_post(agent) do
    fn _url, _headers, _body ->
      Agent.update(agent, &(&1 + 1))
      {:ok, 200, fixture("token.json")}
    end
  end

  defp ok_http do
    fn
      :get, url, _headers, nil ->
        cond do
          String.contains?(url, "currently-playing") -> {:ok, 200, fixture("currently_playing.json")}
          String.contains?(url, "/me/player/queue") -> {:ok, 200, fixture("queue.json")}
          String.contains?(url, "/me/playlists") -> {:ok, 200, fixture("playlists.json")}
          String.contains?(url, "/me/player") -> {:ok, 200, fixture("player.json")}
        end
    end
  end

  test "refresh_if_needed reuses a still-fresh cached token without calling http_post" do
    {:ok, agent} = Agent.start_link(fn -> 0 end)
    token = fresh_token()

    assert {:ok, ^token} = Fetch.refresh_if_needed(config(), token, counting_http_post(agent))
    assert Agent.get(agent, & &1) == 0
  end

  test "refresh_if_needed refreshes when there is no cached token" do
    {:ok, agent} = Agent.start_link(fn -> 0 end)

    assert {:ok, %{access_token: "test-access-token"}} =
             Fetch.refresh_if_needed(config(), nil, counting_http_post(agent))

    assert Agent.get(agent, & &1) == 1
  end

  test "refresh_if_needed refreshes an expired-token as a retry" do
    {:ok, agent} = Agent.start_link(fn -> 0 end)

    assert {:ok, %{access_token: "test-access-token"}} =
             Fetch.refresh_if_needed(config(), expired_token(), counting_http_post(agent))

    assert Agent.get(agent, & &1) == 1
  end

  test "refresh_if_needed refreshes a token inside the expiry buffer window" do
    {:ok, agent} = Agent.start_link(fn -> 0 end)
    about_to_expire = fresh_token(5)

    assert {:ok, %{access_token: "test-access-token"}} =
             Fetch.refresh_if_needed(config(), about_to_expire, counting_http_post(agent))

    assert Agent.get(agent, & &1) == 1
  end

  test "fetch_snapshot surfaces a token refresh failure without calling the API client" do
    http_post = fn _url, _headers, _body -> {:ok, 401, ~s({"error":"invalid_grant"})} end
    http = fn _method, _url, _headers, _body -> flunk("client should not be called") end

    assert {:error, {:http_status, 401, _}} = Fetch.fetch_snapshot(config(), nil, http_post, http)
  end

  test "fetch_snapshot surfaces a Spotify API failure after a successful token refresh" do
    http_post = fn _url, _headers, _body -> {:ok, 200, fixture("token.json")} end
    http = fn :get, _url, _headers, nil -> {:error, :econnrefused} end

    assert {:error, :econnrefused} = Fetch.fetch_snapshot(config(), nil, http_post, http)
  end

  test "fetch_snapshot reuses the cached token and returns it unchanged on success" do
    token = fresh_token()
    http_post = fn _url, _headers, _body -> flunk("should not refresh a fresh token") end

    assert {:ok, snapshot, ^token} = Fetch.fetch_snapshot(config(), token, http_post, ok_http())
    assert snapshot["stale"] == false
  end

  test "fetch_playlists surfaces a token refresh failure without calling the API client" do
    http_post = fn _url, _headers, _body -> {:error, :timeout} end
    http = fn _method, _url, _headers, _body -> flunk("client should not be called") end

    assert {:error, :timeout} = Fetch.fetch_playlists(config(), nil, http_post, http)
  end

  test "fetch_playlists refreshes an expired token then fetches the library" do
    {:ok, agent} = Agent.start_link(fn -> 0 end)

    assert {:ok, snapshot, %{access_token: "test-access-token"}} =
             Fetch.fetch_playlists(config(), expired_token(), counting_http_post(agent), ok_http())

    assert Agent.get(agent, & &1) == 1
    assert snapshot.stale == false
  end
end
