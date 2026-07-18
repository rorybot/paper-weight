defmodule PaperWeight.Application do
  @moduledoc """
  Top-level supervisor. Each domain service is independently enabled/disabled
  via `:paper_weight_host, <service>_service:` config so a given deployment
  (or the zero-env test suite) can run any subset of Weather/Spotify/Feed/Photo.
  """

  use Application

  @type service_state :: :enabled | :disabled

  @type config :: %{
          weather: service_state(),
          spotify: service_state(),
          feed: service_state(),
          photo: service_state(),
          photo_library_dir: String.t() | nil,
          gateway: service_state(),
          gateway_port: pos_integer()
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
    %{
      weather: service_state(:weather_service, :enabled),
      spotify: service_state(:spotify_service, :disabled),
      feed: service_state(:feed_service, :disabled),
      photo: service_state(:photo_service, :disabled),
      photo_library_dir: System.get_env("PAPER_WEIGHT_PHOTO_LIBRARY_DIR"),
      gateway: service_state(:gateway_service, :enabled),
      gateway_port: Application.get_env(:paper_weight_host, :gateway_port, 9138)
    }
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

  defp gateway_child(%{gateway: :enabled, gateway_port: port} = config) do
    adapters = %{
      weather: enabled_ref(config.weather, PaperWeight.Weather.Service),
      spotify: enabled_ref(config.spotify, PaperWeight.Spotify.Service),
      feed: enabled_ref(config.feed, PaperWeight.Feed.Service),
      photo: enabled_ref(config.photo, PaperWeight.Photo.Service)
    }

    [
      {Bandit, plug: {PaperWeight.Gateway.Endpoint, adapters: adapters}, port: port}
    ]
  end

  defp enabled_ref(:enabled, module), do: module
  defp enabled_ref(:disabled, _module), do: nil
end
