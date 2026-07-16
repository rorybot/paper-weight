defmodule PaperWeight.Spotify.AuthTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Spotify.{Auth, Config}

  @fixture_dir Path.join([__DIR__, "fixtures"])

  defp fixture(name), do: File.read!(Path.join(@fixture_dir, name))

  defp config do
    Config.new(
      client_id: "cid",
      client_secret: "csecret",
      refresh_token: "rtoken",
      accounts_token_url: "https://accounts.spotify.test/api/token"
    )
  end

  test "refresh_access_token exchanges the refresh token for an access token" do
    http_post = fn url, headers, body ->
      assert url == "https://accounts.spotify.test/api/token"
      assert Enum.any?(headers, fn {k, _} -> k == "content-type" end)
      assert body =~ "grant_type=refresh_token"
      assert body =~ "rtoken"
      {:ok, 200, fixture("token.json")}
    end

    assert {:ok, %{access_token: "test-access-token", expires_at: %DateTime{}}} =
             Auth.refresh_access_token(config(), http_post)
  end

  test "refresh_access_token surfaces non-200 responses" do
    http_post = fn _url, _headers, _body -> {:ok, 401, ~s({"error":"invalid_grant"}) } end

    assert {:error, {:http_status, 401, _body}} = Auth.refresh_access_token(config(), http_post)
  end

  test "refresh_access_token surfaces transport errors" do
    http_post = fn _url, _headers, _body -> {:error, :timeout} end

    assert {:error, :timeout} = Auth.refresh_access_token(config(), http_post)
  end

  test "refresh_access_token requires client_id/secret/refresh_token to be configured" do
    empty_config = Config.new(client_id: nil, client_secret: nil, refresh_token: nil)
    http_post = fn _url, _headers, _body -> flunk("should not be called") end

    assert {:error, {:missing_config, :client_id}} =
             Auth.refresh_access_token(empty_config, http_post)
  end
end
