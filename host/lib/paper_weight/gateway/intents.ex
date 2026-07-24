defmodule PaperWeight.Gateway.Intents do
  @moduledoc """
  Pure validation plus injected dispatch for device-to-host intent frames.

  Invalid JSON, wrong protocol versions, unknown intent names, and invalid arguments are returned
  as errors for the socket edge to log and drop. Service modules are injected so dispatch remains
  deterministic in tests and no malformed input can crash the WebSocket process.
  """

  alias PaperWeight.{Photo, Spotify, Weather}
  alias PaperWeight.Spotify.JsonLite

  @channels ~w(now_playing weather photo etymology playlist system)

  @type intent ::
          {:set_volume, integer()}
          | {:play_playlist, String.t()}
          | {:play_queue_item, String.t()}
          | {:refresh_channel, String.t()}

  @type adapters :: map()
  @type handlers :: %{
          set_volume: (GenServer.server(), integer() -> term()),
          play_playlist: (GenServer.server(), String.t() -> term()),
          play_queue_item: (GenServer.server(), String.t() -> term()),
          refresh_weather: (GenServer.server() -> term()),
          refresh_photo: (GenServer.server() -> term()),
          refresh_spotify: (GenServer.server() -> term())
        }

  @spec decode(binary()) :: {:ok, intent()} | {:error, term()}
  def decode(frame) when is_binary(frame) do
    with {:ok, value} <- decode_json(frame),
         {:ok, intent} <- validate(value) do
      {:ok, intent}
    end
  end

  @spec dispatch(intent(), adapters(), handlers()) :: :ok | {:error, term()}
  def dispatch(intent, adapters, handlers \\ default_handlers())

  def dispatch({:set_volume, delta}, adapters, handlers) do
    call(adapters[:spotify], fn server -> handlers.set_volume.(server, delta) end)
  end

  def dispatch({:play_playlist, id}, adapters, handlers) do
    call(adapters[:spotify], fn server -> handlers.play_playlist.(server, id) end)
  end

  def dispatch({:play_queue_item, id}, adapters, handlers) do
    call(adapters[:spotify], fn server -> handlers.play_queue_item.(server, id) end)
  end

  def dispatch({:refresh_channel, "now_playing"}, adapters, handlers) do
    call(adapters[:spotify], handlers.refresh_spotify)
  end

  def dispatch({:refresh_channel, "weather"}, adapters, handlers) do
    call(adapters[:weather], handlers.refresh_weather)
  end

  def dispatch({:refresh_channel, "photo"}, adapters, handlers) do
    call(adapters[:photo], handlers.refresh_photo)
  end

  def dispatch({:refresh_channel, channel}, _adapters, _handlers)
      when channel in ["playlist", "etymology", "system"],
      do: {:error, {:unsupported_refresh, channel}}

  @spec default_handlers() :: handlers()
  def default_handlers do
    %{
      set_volume: &Spotify.Service.set_volume/2,
      play_playlist: &Spotify.Service.play_playlist/2,
      play_queue_item: &Spotify.Service.play_track/2,
      refresh_weather: &Weather.Service.refresh_now/1,
      refresh_photo: &Photo.Service.rescan/1,
      refresh_spotify: &Spotify.Service.refresh_now/1
    }
  end

  defp validate(%{
         "v" => 1,
         "type" => "intent",
         "name" => "set_volume",
         "args" => %{"delta" => delta}
       })
       when is_integer(delta),
       do: {:ok, {:set_volume, delta}}

  defp validate(%{
         "v" => 1,
         "type" => "intent",
         "name" => "play_playlist",
         "args" => %{"id" => id}
       })
       when is_binary(id) and id != "",
       do: {:ok, {:play_playlist, id}}

  defp validate(%{
         "v" => 1,
         "type" => "intent",
         "name" => "play_queue_item",
         "args" => %{"id" => id}
       })
       when is_binary(id) and id != "",
       do: {:ok, {:play_queue_item, id}}

  defp validate(%{
         "v" => 1,
         "type" => "intent",
         "name" => "refresh_channel",
         "args" => %{"channel" => channel}
       })
       when channel in @channels,
       do: {:ok, {:refresh_channel, channel}}

  defp validate(%{"v" => version}) when version != 1, do: {:error, :wrong_version}
  defp validate(%{"type" => type}) when type != "intent", do: {:error, :wrong_type}
  defp validate(%{"name" => name}) when is_binary(name), do: {:error, {:invalid_intent, name}}
  defp validate(_value), do: {:error, :invalid_intent}

  defp decode_json(frame) do
    if Code.ensure_loaded?(:json) and function_exported?(:json, :decode, 1) do
      try do
        {:ok, :json.decode(frame)}
      rescue
        _exception -> {:error, :invalid_json}
      end
    else
      case JsonLite.decode(frame) do
        {:ok, value} -> {:ok, value}
        {:error, _reason} -> {:error, :invalid_json}
      end
    end
  end

  defp call(nil, _fun), do: {:error, :service_disabled}

  defp call(server, fun) do
    case fun.(server) do
      {:error, reason} -> {:error, {:dispatch_failed, reason}}
      _success -> :ok
    end
  catch
    :exit, _reason -> {:error, :service_unavailable}
  end
end
