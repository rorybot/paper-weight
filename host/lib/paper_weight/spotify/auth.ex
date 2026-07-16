defmodule PaperWeight.Spotify.Auth do
  @moduledoc """
  Impure edge: OAuth refresh-token exchange against Spotify Accounts API.

  HTTP is injected as `http_post.(url, headers, body) -> {:ok, status, body} | {:error, reason}`
  so tests never hit the network. Secrets flow through `Config` only — never logged.
  """

  alias PaperWeight.Spotify.{Config, JsonLite}

  @type http_post ::
          (String.t(), [{String.t(), String.t()}], binary() ->
             {:ok, pos_integer(), binary()} | {:error, term()})

  @type token :: %{access_token: String.t(), expires_at: DateTime.t()}

  @spec refresh_access_token(Config.t(), http_post()) :: {:ok, token()} | {:error, term()}
  def refresh_access_token(config, http_post) when is_function(http_post, 3) do
    with {:ok, client_id} <- require_field(config, :client_id),
         {:ok, client_secret} <- require_field(config, :client_secret),
         {:ok, refresh_token} <- require_field(config, :refresh_token) do
      body =
        URI.encode_query(%{
          "grant_type" => "refresh_token",
          "refresh_token" => refresh_token,
          "client_id" => client_id,
          "client_secret" => client_secret
        })

      headers = [{"content-type", "application/x-www-form-urlencoded"}]

      case http_post.(config.accounts_token_url, headers, body) do
        {:ok, 200, resp_body} -> parse_token(resp_body)
        {:ok, status, resp_body} -> {:error, {:http_status, status, resp_body}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Default HTTP POST using Erlang `:httpc`. Requires `:inets` / `:ssl` in
  `extra_applications` for live calls — see deps request. Tests always inject a mock.
  """
  @spec default_http_post() :: http_post()
  def default_http_post do
    fn url, headers, body ->
      httpc_post(url, headers, body)
    end
  end

  defp httpc_post(url, headers, body) do
    if Code.ensure_loaded?(:httpc) do
      _ = Application.ensure_all_started(:inets)
      _ = Application.ensure_all_started(:ssl)

      content_type =
        headers
        |> Enum.find({"content-type", "application/x-www-form-urlencoded"}, fn {k, _} ->
          String.downcase(k) == "content-type"
        end)
        |> elem(1)
        |> String.to_charlist()

      other_headers =
        headers
        |> Enum.reject(fn {k, _} -> String.downcase(k) == "content-type" end)
        |> Enum.map(fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)

      request = {String.to_charlist(url), other_headers, content_type, body}

      case apply(:httpc, :request, [:post, request, [timeout: 15_000], [body_format: :binary]]) do
        {:ok, {{_, status, _}, _hdrs, resp_body}} when is_binary(resp_body) ->
          {:ok, status, resp_body}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :httpc_unavailable}
    end
  end

  defp require_field(config, key) do
    case Map.get(config, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, {:missing_config, key}}
    end
  end

  defp parse_token(body) do
    with {:ok, json} <- json_decode(body),
         %{"access_token" => access_token, "expires_in" => expires_in} <- json,
         true <- is_binary(access_token),
         true <- is_integer(expires_in) do
      {:ok, %{access_token: access_token, expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)}}
    else
      _ -> {:error, {:bad_token_response, body}}
    end
  end

  defp json_decode(body) do
    if Code.ensure_loaded?(:json) and function_exported?(:json, :decode, 1) do
      try do
        {:ok, :json.decode(body)}
      rescue
        e -> {:error, {:json_decode, e}}
      end
    else
      JsonLite.decode(body)
    end
  end
end
