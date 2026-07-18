defmodule PaperWeight.Application do
  @moduledoc """
  Top-level supervisor. Each domain service is independently enabled/disabled
  via `:paper_weight_host, <service>_service:` config so a given deployment
  (or the zero-env test suite) can run any subset of Weather/Spotify/Feed/Photo.

  ## Smoke profile (`gateway: [stubs: :all]`)

  Set env `PAPER_WEIGHT_GATEWAY_STUBS=all` (or config `gateway_stubs: :all`).
  Starts fixture-backed stub adapters for every managed channel, enables the
  gateway on `gateway_port` (default 9138), and skips real domain services so
  desktop smoke needs no API secrets. See `docs/architecture/wave-3-smoke.md`.
  """

  use Application

  alias PaperWeight.Gateway.Stubs

  @type service_state :: :enabled | :disabled
  @type stubs_mode :: :none | :all

  @type config :: %{
          weather: service_state(),
          spotify: service_state(),
          feed: service_state(),
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
    |> Kernel.++(service_child(config.feed, PaperWeight.Feed.Service))
    |> Kernel.++(photo_child(config))
    |> Kernel.++(gateway_child(config))
  end

  @spec config_from_env() :: config()
  def config_from_env do
    stubs = stubs_mode()

    base = %{
      weather: service_state(:weather_service, :enabled),
      spotify: service_state(:spotify_service, :disabled),
      feed: service_state(:feed_service, :disabled),
      photo: service_state(:photo_service, :disabled),
      photo_library_dir: System.get_env("PAPER_WEIGHT_PHOTO_LIBRARY_DIR"),
      gateway: service_state(:gateway_service, :enabled),
      gateway_port: Application.get_env(:paper_weight_host, :gateway_port, 9138),
      gateway_stubs: stubs
    }

    case stubs do
      :all ->
        # Stub profile owns adapters; real services stay off to avoid name/API conflicts.
        %{
          base
          | weather: :disabled,
            spotify: :disabled,
            feed: :disabled,
            photo: :disabled,
            gateway: :enabled
        }

      :none ->
        base
    end
  end

  defp stubs_mode do
    env = System.get_env("PAPER_WEIGHT_GATEWAY_STUBS")

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
      feed: enabled_ref(config.feed, PaperWeight.Feed.Service),
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
