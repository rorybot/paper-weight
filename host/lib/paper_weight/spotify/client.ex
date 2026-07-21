defmodule PaperWeight.Spotify.Client do
  @moduledoc """
  Impure edge: Spotify Web API player reads, volume write, and playlist list.

  HTTP is injected as `http.(method, url, headers, body) -> {:ok, status, body} | {:error, reason}`
  so tests never hit the network.

  **Explicit ban:** no generic `play`, `pause`, `skip`, or `previous`. Only explicit,
  device-selected targets are allowed: `play_playlist/4` (W3-E, playlist screen) and
  `play_track/4` (N6, the queue item the device chose on Now Playing).
  """

  alias PaperWeight.Spotify.{Config, JsonLite}

  @type http ::
          (:get | :put, String.t(), [{String.t(), String.t()}], binary() | nil ->
             {:ok, pos_integer(), binary()} | {:error, term()})

  @type track :: %{
          title: String.t(),
          artist: String.t(),
          album: String.t(),
          art_url: String.t() | nil,
          duration_ms: non_neg_integer(),
          progress_ms: non_neg_integer()
        }

  @type playlist_item :: %{
          id: String.t(),
          name: String.t(),
          cover_pbm_base64: nil
        }

  # First page only — enough for the 2×3 playlist grid; pagination is out of scope.
  @playlists_limit 50

  # Bounded queue snapshot — the device shows a scrollable Up-Next list, not the full backlog.
  @queue_limit 20

  # Device art pane is 152×152 (now-playing.css); pick the smallest Spotify-provided
  # image at least this wide so we download the least data before downscaling.
  @art_target_px 152

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
          {:ok, [%{id: String.t(), title: String.t(), artist: String.t()}]} | {:error, term()}
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
    url =
      config.api_base <> "/me/player/volume?" <> URI.encode_query(%{"volume_percent" => level})

    case http.(:put, url, auth_headers(access_token), "") do
      {:ok, status, _body} when status in [200, 202, 204] -> {:ok, level}
      {:ok, status, body} -> {:error, {:http_status, status, body}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec play_playlist(Config.t(), String.t(), String.t(), http()) :: :ok | {:error, term()}
  def play_playlist(config, access_token, playlist_id, http)
      when is_function(http, 4) and is_binary(playlist_id) do
    with true <- valid_playlist_id?(playlist_id) do
      url = config.api_base <> "/me/player/play"
      body = ~s({"context_uri":"spotify:playlist:#{playlist_id}"})

      headers = auth_headers(access_token) ++ [{"Content-Type", "application/json"}]

      case http.(:put, url, headers, body) do
        {:ok, status, _body} when status in [200, 202, 204] -> :ok
        {:ok, status, response_body} -> {:error, {:http_status, status, response_body}}
        {:error, reason} -> {:error, reason}
      end
    else
      false -> {:error, :invalid_playlist_id}
    end
  end

  @doc """
  Play a single, device-selected track by id (a `queue[].id` from the snapshot).

  Starts `spotify:track:<id>` via `PUT /me/player/play` — the explicit N6 counterpart to
  `play_playlist/4`. Still no generic skip/next/previous.
  """
  @spec play_track(Config.t(), String.t(), String.t(), http()) :: :ok | {:error, term()}
  def play_track(config, access_token, track_id, http)
      when is_function(http, 4) and is_binary(track_id) do
    with true <- valid_track_id?(track_id) do
      url = config.api_base <> "/me/player/play"
      body = ~s({"uris":["spotify:track:#{track_id}"]})

      headers = auth_headers(access_token) ++ [{"Content-Type", "application/json"}]

      case http.(:put, url, headers, body) do
        {:ok, status, _body} when status in [200, 202, 204] -> :ok
        {:ok, status, response_body} -> {:error, {:http_status, status, response_body}}
        {:error, reason} -> {:error, reason}
      end
    else
      false -> {:error, :invalid_track_id}
    end
  end

  @doc """
  List the current user's playlists (first page).

  Covers ship as `cover_pbm_base64: nil` — playlist cover download/decode is a
  separate lane from now-playing art (N5 #128) and stays out of scope here.
  Device falls back to CSS hatch.
  """
  @spec playlists(Config.t(), String.t(), http()) ::
          {:ok, [playlist_item()]} | {:error, term()}
  def playlists(config, access_token, http) when is_function(http, 4) do
    url =
      config.api_base <>
        "/me/playlists?" <> URI.encode_query(%{"limit" => Integer.to_string(@playlists_limit)})

    case http.(:get, url, auth_headers(access_token), nil) do
      {:ok, 200, body} -> parse_playlists(body)
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

      charlist_headers =
        Enum.map(headers, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)

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

  defp valid_playlist_id?(id), do: id != "" and Regex.match?(~r/^[A-Za-z0-9]+$/, id)

  defp valid_track_id?(id), do: id != "" and Regex.match?(~r/^[A-Za-z0-9]+$/, id)

  defp parse_now_playing(body) do
    with {:ok, json} <- json_decode(body),
         %{"item" => item} when is_map(item) <- json do
      {:ok,
       %{
         title: Map.get(item, "name", ""),
         artist: artist_names(item),
         album: get_in(item, ["album", "name"]) || "",
         art_url: album_art_url(item),
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
       queue
       |> Enum.take(@queue_limit)
       |> Enum.map(fn item ->
         %{
           id: Map.get(item, "id", ""),
           title: Map.get(item, "name", ""),
           artist: artist_names(item)
         }
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

  defp parse_playlists(body) do
    with {:ok, %{"items" => items}} when is_list(items) <- json_decode(body) do
      playlists =
        items
        |> Enum.map(&playlist_item/1)
        |> Enum.reject(&is_nil/1)

      {:ok, playlists}
    else
      _ -> {:error, {:bad_playlists_response, body}}
    end
  end

  defp playlist_item(%{"id" => id, "name" => name})
       when is_binary(id) and id != "" and is_binary(name) do
    %{id: id, name: name, cover_pbm_base64: nil}
  end

  defp playlist_item(_), do: nil

  defp album_art_url(item) do
    case get_in(item, ["album", "images"]) do
      images when is_list(images) and images != [] ->
        candidates = Enum.filter(images, &(is_map(&1) and is_binary(&1["url"])))

        smallest_big_enough =
          candidates
          |> Enum.filter(&(Map.get(&1, "width", 0) >= @art_target_px))
          |> Enum.min_by(&Map.get(&1, "width", 0), fn -> nil end)

        largest = Enum.max_by(candidates, &Map.get(&1, "width", 0), fn -> nil end)

        case smallest_big_enough || largest do
          %{"url" => url} -> url
          nil -> nil
        end

      _ ->
        nil
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
