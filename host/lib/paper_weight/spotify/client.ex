defmodule PaperWeight.Spotify.Client do
  @moduledoc """
  Impure edge: Spotify Web API player reads + volume write.

  HTTP is injected as `http.(method, url, headers, body) -> {:ok, status, body} | {:error, reason}`
  so tests never hit the network.

  **Explicit ban:** no `play`, `pause`, `skip`, or `previous` here — volume only.
  """

  alias PaperWeight.Spotify.{Config, JsonLite}

  @type http ::
          (:get | :put, String.t(), [{String.t(), String.t()}], binary() | nil ->
             {:ok, pos_integer(), binary()} | {:error, term()})

  @type track :: %{
          title: String.t(),
          artist: String.t(),
          album: String.t(),
          duration_ms: non_neg_integer(),
          progress_ms: non_neg_integer()
        }

  @spec now_playing(Config.t(), String.t(), http()) ::
          {:ok, track() | :none} | {:error, term()}
  def now_playing(config, access_token, http) when is_function(http, 4) do
    url = config.api_base <> "/me/player/currently-playing"

    case http.(:get, url, auth_headers(access_token), nil) do
      {:ok, 200, ""} -> {:ok, :none}
      {:ok, 204, _} -> {:ok, :none}
      {:ok, 200, body} -> parse_now_playing(body)
      {:ok, status, body} -> {:error, {:http_status, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec queue(Config.t(), String.t(), http()) ::
          {:ok, [%{title: String.t(), artist: String.t()}]} | {:error, term()}
  def queue(config, access_token, http) when is_function(http, 4) do
    url = config.api_base <> "/me/player/queue"

    case http.(:get, url, auth_headers(access_token), nil) do
      {:ok, 200, body} -> parse_queue(body)
      {:ok, status, body} -> {:error, {:http_status, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec volume(Config.t(), String.t(), http()) :: {:ok, 0..100} | {:error, term()}
  def volume(config, access_token, http) when is_function(http, 4) do
    url = config.api_base <> "/me/player"

    case http.(:get, url, auth_headers(access_token), nil) do
      {:ok, 200, ""} -> {:ok, 0}
      {:ok, 204, _} -> {:ok, 0}
      {:ok, 200, body} -> parse_volume(body)
      {:ok, status, body} -> {:error, {:http_status, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec set_volume(Config.t(), String.t(), 0..100, http()) :: {:ok, 0..100} | {:error, term()}
  def set_volume(config, access_token, level, http)
      when is_function(http, 4) and is_integer(level) and level >= 0 and level <= 100 do
    url = config.api_base <> "/me/player/volume?" <> URI.encode_query(%{"volume_percent" => level})

    case http.(:put, url, auth_headers(access_token), "") do
      {:ok, status, _body} when status in [200, 202, 204] -> {:ok, level}
      {:ok, status, body} -> {:error, {:http_status, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Default HTTP client using Erlang `:httpc`. Requires `:inets` / `:ssl` in
  `extra_applications` for live calls — see deps request. Tests always inject a mock.
  """
  @spec default_http() :: http()
  def default_http do
    fn method, url, headers, body ->
      httpc_request(method, url, headers, body)
    end
  end

  defp httpc_request(method, url, headers, body) do
    if Code.ensure_loaded?(:httpc) do
      _ = Application.ensure_all_started(:inets)
      _ = Application.ensure_all_started(:ssl)

      charlist_headers = Enum.map(headers, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)

      result =
        case method do
          :get ->
            apply(:httpc, :request, [
              :get,
              {String.to_charlist(url), charlist_headers},
              [timeout: 15_000],
              [body_format: :binary]
            ])

          :put ->
            apply(:httpc, :request, [
              :put,
              {String.to_charlist(url), charlist_headers, ~c"application/json", body || ""},
              [timeout: 15_000],
              [body_format: :binary]
            ])
        end

      case result do
        {:ok, {{_, status, _}, _hdrs, resp_body}} when is_binary(resp_body) ->
          {:ok, status, resp_body}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :httpc_unavailable}
    end
  end

  defp auth_headers(access_token) do
    [{"Authorization", "Bearer " <> access_token}]
  end

  defp parse_now_playing(body) do
    with {:ok, json} <- json_decode(body),
         %{"item" => item} when is_map(item) <- json do
      {:ok,
       %{
         title: Map.get(item, "name", ""),
         artist: artist_names(item),
         album: get_in(item, ["album", "name"]) || "",
         duration_ms: Map.get(item, "duration_ms", 0),
         progress_ms: Map.get(json, "progress_ms", 0)
       }}
    else
      %{"item" => nil} -> {:ok, :none}
      _ -> {:error, {:bad_now_playing_response, body}}
    end
  end

  defp parse_queue(body) do
    with {:ok, %{"queue" => queue}} when is_list(queue) <- json_decode(body) do
      {:ok,
       Enum.map(queue, fn item ->
         %{title: Map.get(item, "name", ""), artist: artist_names(item)}
       end)}
    else
      _ -> {:error, {:bad_queue_response, body}}
    end
  end

  defp parse_volume(body) do
    case json_decode(body) do
      {:ok, %{"device" => %{"volume_percent" => level}}} when is_integer(level) ->
        {:ok, level}

      {:ok, _} ->
        {:ok, 0}

      {:error, _} = err ->
        err
    end
  end

  defp artist_names(%{"artists" => artists}) when is_list(artists) do
    artists
    |> Enum.map(&Map.get(&1, "name", ""))
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(", ")
  end

  defp artist_names(_), do: ""

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
