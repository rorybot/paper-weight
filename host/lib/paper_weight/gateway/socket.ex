defmodule PaperWeight.Gateway.Socket do
  @moduledoc """
  WebSock socket for the wave-3 gateway. Pushes one envelope per enabled
  channel on connect, then polls each backing service and re-pushes only the
  channels whose `gen` advanced. Inbound frames are dropped — frame handling
  is W3-E's job (#48).

  `init/1` receives a `PaperWeight.Gateway.adapters()` map of
  `channel => GenServer.server() | nil` (`nil` = disabled). Adapter calls are
  wrapped in `fetch/3` so a dead/missing service degrades to `:disabled`
  rather than crashing the socket.
  """

  @behaviour WebSock

  alias PaperWeight.Gateway.{JsonEncoder, Publisher}
  alias PaperWeight.{Feed, Photo, Spotify, Weather}

  @poll_ms 1_000

  @type adapters :: %{
          weather: GenServer.server() | nil,
          spotify: GenServer.server() | nil,
          feed: GenServer.server() | nil,
          photo: GenServer.server() | nil
        }

  @impl WebSock
  def init(adapters) do
    state = %{adapters: adapters, gens: %{}}
    {frames, state} = push_all(state)
    {:push, frames, schedule(state)}
  end

  @impl WebSock
  def handle_in(_frame, state), do: {:ok, state}

  @impl WebSock
  def handle_info(:poll, state) do
    {frames, state} = push_changed(state)
    state = schedule(state)

    case frames do
      [] -> {:ok, state}
      _ -> {:push, frames, state}
    end
  end

  def handle_info(_msg, state), do: {:ok, state}

  defp push_all(state) do
    envelopes = Publisher.envelopes(collect_inputs(state.adapters))
    gens = Map.new(envelopes, &{&1.channel, &1.gen})
    {Enum.map(envelopes, &frame/1), %{state | gens: gens}}
  end

  defp push_changed(state) do
    envelopes = Publisher.envelopes(collect_inputs(state.adapters))
    changed = Enum.filter(envelopes, fn env -> Map.get(state.gens, env.channel) != env.gen end)
    gens = Enum.reduce(changed, state.gens, fn env, acc -> Map.put(acc, env.channel, env.gen) end)
    {Enum.map(changed, &frame/1), %{state | gens: gens}}
  end

  defp frame(envelope), do: {:text, JsonEncoder.encode!(envelope)}

  defp schedule(state) do
    Process.send_after(self(), :poll, @poll_ms)
    state
  end

  @spec collect_inputs(adapters()) :: Publisher.inputs()
  def collect_inputs(adapters) do
    %{
      weather:
        fetch(adapters[:weather], &Weather.Service.get_snapshot/1, &Weather.Service.get_gen/1),
      spotify:
        fetch(adapters[:spotify], &Spotify.Service.now_playing/1, &Spotify.Service.get_gen/1),
      feed: feed_input(adapters[:feed]),
      photo: fetch(adapters[:photo], &Photo.Service.get_snapshot/1, &Photo.Service.get_gen/1)
    }
  end

  defp fetch(nil, _snapshot_fun, _gen_fun), do: :disabled

  defp fetch(server, snapshot_fun, gen_fun) do
    case snapshot_fun.(server) do
      {:ok, snapshot} -> {:ok, snapshot, gen_fun.(server)}
      {:error, reason} -> {:error, reason}
    end
  catch
    :exit, _reason -> {:error, :service_unavailable}
  end

  defp feed_input(nil), do: :disabled

  defp feed_input(server) do
    %{gen: gen, snapshot: snapshot} = Feed.Service.current(server)
    {:ok, snapshot, gen}
  catch
    :exit, _reason -> {:error, :service_unavailable}
  end
end
