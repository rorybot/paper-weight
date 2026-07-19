defmodule PaperWeight.Weather.Fetch do
  @moduledoc """
  Impure edge: single HTTP fetch of Open-Meteo forecast data into a WeatherSnapshotV1 map.

  HTTP is injected as `http_get.(url, headers) -> {:ok, body_binary} | {:error, reason}`
  so tests never hit the network. No API key is required.
  """

  alias PaperWeight.Weather.{Config, OpenMeteo, Snapshot}

  @type http_get :: (String.t(), [{String.t(), String.t()}] -> {:ok, binary()} | {:error, term()})

  @spec fetch_snapshot(Config.t(), http_get()) :: {:ok, Snapshot.t()} | {:error, term()}
  def fetch_snapshot(config, http_get) when is_function(http_get, 2) do
    with {:ok, body} <- get_json(http_get, Config.open_meteo_url(config), headers(config)),
         {:ok, forecast} <- decode(body),
         {:ok, %{current: current, days: days, uv_index: uv_index, hourly_uv: hourly_uv}} <-
           OpenMeteo.parse(forecast) do
      snapshot =
        Snapshot.assemble(%{
          location_label: config.location_label,
          current: current,
          days: days,
          uv_index: uv_index,
          hourly_uv: hourly_uv,
          stale: false
        })

      {:ok, snapshot}
    end
  end

  @doc """
  Default HTTP client using Erlang `:httpc` when `:inets` is available.

  Application must include `:inets` / `:ssl` in `extra_applications` for live
  calls (orchestrator deps wave). Tests always inject a mock client.
  """
  @spec default_http_get() :: http_get()
  def default_http_get do
    fn url, headers ->
      httpc_get(url, headers)
    end
  end

  defp httpc_get(url, headers) do
    # apply/3 avoids compile-time warnings when :inets is not in extra_applications yet.
    if Code.ensure_loaded?(:httpc) do
      _ = Application.ensure_all_started(:inets)
      _ = Application.ensure_all_started(:ssl)

      request = {
        String.to_charlist(url),
        Enum.map(headers, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)
      }

      case apply(:httpc, :request, [:get, request, [timeout: 15_000], [body_format: :binary]]) do
        {:ok, {{_, 200, _}, _hdrs, body}} when is_binary(body) ->
          {:ok, body}

        {:ok, {{_, status, _}, _hdrs, body}} ->
          {:error, {:http_status, status, body}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :httpc_unavailable}
    end
  end

  defp headers(config) do
    [{"User-Agent", config.user_agent}]
  end

  defp get_json(http_get, url, headers) do
    http_get.(url, headers)
  end

  defp decode(body) when is_binary(body) do
    case json_decode(body) do
      {:ok, map} when is_map(map) -> {:ok, map}
      {:ok, _} -> {:error, :json_not_object}
      {:error, reason} -> {:error, reason}
    end
  end

  # Prefer stdlib :json (OTP 27+); fall back to a minimal decoder for maps we control in tests.
  defp json_decode(body) do
    if Code.ensure_loaded?(:json) and function_exported?(:json, :decode, 1) do
      try do
        {:ok, :json.decode(body)}
      rescue
        e -> {:error, {:json_decode, e}}
      end
    else
      PaperWeight.Weather.JsonLite.decode(body)
    end
  end
end
