defmodule PaperWeight.Application do
  @moduledoc """
  Top-level supervisor. Each domain service is independently enabled/disabled
  via `:paper_weight_host, <service>_service:` config so a given deployment
  (or the zero-env test suite) can run any subset of Weather/Spotify/Photo.

  ## Smoke profile (`gateway: [stubs: :all]`)

  Set env `PAPER_WEIGHT_GATEWAY_STUBS=all` (or config `gateway_stubs: :all`).
  Starts fixture-backed stub adapters for every managed channel, enables the
  gateway on `gateway_port` (default 9138), and skips real domain services so
  desktop smoke needs no API secrets. See `docs/architecture/wave-3-smoke.md`.

  ## Live-runtime contract (P7)

  Weather/Spotify can each be switched between compiled default and
  live at runtime via `PAPER_WEIGHT_WEATHER_ENABLED` / `PAPER_WEIGHT_SPOTIFY_ENABLED`
  (`true`/`1`/`enabled` or `false`/`0`/`disabled`,
  case-insensitive; unset falls back to the compiled `config.exs` default).
  `PAPER_WEIGHT_GATEWAY_STUBS=all` still overrides both to `:disabled`
  regardless of these vars. An enabled lane with missing/empty required env
  vars fails boot loudly (var *names* only, never values) rather than
  starting broken. Full contract: `docs/architecture/live-runtime-contract-v1.md`.
  """

  use Application

  alias PaperWeight.Gateway.Stubs
  alias PaperWeight.RuntimeContract

  @type service_state :: :enabled | :disabled
  @type stubs_mode :: :none | :all

  @type config :: %{
          weather: service_state(),
          spotify: service_state(),
          photo: service_state(),
          photo_library_dir: String.t() | nil,
          gateway: service_state(),
          gateway_port: pos_integer(),
          gateway_stubs: stubs_mode()
        }

  @impl true
  def start(_type, _args) do
    children = children(config_from_env())

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: PaperWeight.Supervisor
    )
  end

  @doc """
  Pure: builds the supervisor child spec list from a resolved `config()`. No
  env/Application lookups here — see `config_from_env/0` for the impure edge.
  """
  @spec children(config()) :: [Supervisor.child_spec() | {module(), keyword()}]
  def children(%{gateway_stubs: :all} = config) do
    [{PaperWeight.Dither.Cache, name: PaperWeight.Dither.Cache}]
    |> Kernel.++(Stubs.children())
    |> Kernel.++(gateway_child_with_adapters(config, Stubs.adapters()))
  end

  def children(config) do
    [{PaperWeight.Dither.Cache, name: PaperWeight.Dither.Cache}]
    |> Kernel.++(service_child(config.weather, PaperWeight.Weather.Service))
    |> Kernel.++(service_child(config.spotify, PaperWeight.Spotify.Service))
    |> Kernel.++(photo_child(config))
    |> Kernel.++(gateway_child(config))
  end

  @type getenv :: (String.t() -> String.t() | nil)

  @spec config_from_env() :: config()
  def config_from_env, do: resolve_config(&System.get_env/1)

  @doc """
  Pure decision layer behind `config_from_env/0`, injectable for tests. Takes
  one env-lookup function so env-driven enable/disable and startup
  validation can be exercised with a fake map instead of mutating real OS
  env vars — this suite runs test modules concurrently, and `System.put_env`
  is process-wide, so a real mutation could race any other test that calls
  `config_from_env/0`.
  """
  @spec resolve_config(getenv()) :: config()
  def resolve_config(getenv) when is_function(getenv, 1) do
    stubs = stubs_mode(getenv)

    base = %{
      weather: lane_state(getenv, "PAPER_WEIGHT_WEATHER_ENABLED", :weather_service, :enabled),
      spotify: lane_state(getenv, "PAPER_WEIGHT_SPOTIFY_ENABLED", :spotify_service, :disabled),
      photo: service_state(:photo_service, :disabled),
      photo_library_dir: getenv.("PAPER_WEIGHT_PHOTO_LIBRARY_DIR"),
      gateway: service_state(:gateway_service, :enabled),
      gateway_port: Application.get_env(:paper_weight_host, :gateway_port, 9138),
      gateway_stubs: stubs
    }

    config =
      case stubs do
        :all ->
          # Stub profile owns adapters; real services stay off to avoid name/API conflicts.
          %{
            base
            | weather: :disabled,
              spotify: :disabled,
              photo: :disabled,
              gateway: :enabled
          }

        :none ->
          base
      end

    validate_live_lanes!(config, getenv)

    config
  end

  defp stubs_mode(getenv) do
    env = getenv.("PAPER_WEIGHT_GATEWAY_STUBS")

    cond do
      env in ["all", "ALL"] ->
        :all

      env in ["none", "NONE", "0", "false", "off"] ->
        :none

      true ->
        case Application.get_env(:paper_weight_host, :gateway_stubs, :none) do
          :all -> :all
          _ -> :none
        end
    end
  end

  defp service_state(key, default) do
    case Application.get_env(:paper_weight_host, key, default) do
      :disabled -> :disabled
      _enabled -> :enabled
    end
  end

  @live_lanes [:weather, :spotify]

  # Raw env wins if it's a recognized literal; otherwise falls back to the
  # existing compiled-config resolution so zero-env behavior is unchanged.
  defp lane_state(getenv, env_var, config_key, default) do
    case getenv.(env_var) do
      nil -> service_state(config_key, default)
      value -> parse_lane_state(value, config_key, default)
    end
  end

  defp parse_lane_state(value, config_key, default) do
    case String.downcase(value) do
      v when v in ["true", "1", "enabled"] -> :enabled
      v when v in ["false", "0", "disabled"] -> :disabled
      _unrecognized -> service_state(config_key, default)
    end
  end

  defp validate_live_lanes!(config, getenv) do
    Enum.each(@live_lanes, fn lane ->
      if Map.fetch!(config, lane) == :enabled do
        case RuntimeContract.missing_vars(lane, getenv) do
          [] ->
            :ok

          missing ->
            raise ArgumentError,
                  "#{lane} enabled but missing required env vars: #{Enum.join(missing, ", ")}"
        end
      end
    end)
  end

  defp service_child(:disabled, _module), do: []
  defp service_child(:enabled, module), do: [{module, [name: module]}]

  defp photo_child(%{photo: :disabled}), do: []

  defp photo_child(%{photo: :enabled, photo_library_dir: dir}) do
    [{PaperWeight.Photo.Service, [name: PaperWeight.Photo.Service, library_dir: dir]}]
  end

  defp gateway_child(%{gateway: :disabled}), do: []

  defp gateway_child(%{gateway: :enabled, gateway_port: _port} = config) do
    adapters = %{
      weather: enabled_ref(config.weather, PaperWeight.Weather.Service),
      spotify: enabled_ref(config.spotify, PaperWeight.Spotify.Service),
      photo: enabled_ref(config.photo, PaperWeight.Photo.Service)
    }

    gateway_child_with_adapters(config, adapters)
  end

  defp gateway_child_with_adapters(%{gateway: :disabled}, _adapters), do: []

  defp gateway_child_with_adapters(%{gateway: :enabled, gateway_port: port}, adapters) do
    [
      {Bandit, plug: {PaperWeight.Gateway.Endpoint, adapters: adapters}, port: port}
    ]
  end

  defp enabled_ref(:enabled, module), do: module
  defp enabled_ref(:disabled, _module), do: nil
end
