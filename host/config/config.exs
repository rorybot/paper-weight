import Config

# Each service below is independently :enabled | :disabled under
# PaperWeight.Application (see children/1 + config_from_env/0). Unit tests
# start their own service instances directly with injected mocks, so the
# test env disables every service and asserts zero-env startup is safe.

# Weather GenServer under PaperWeight.Application.
# :enabled starts {PaperWeight.Weather.Service, [name: PaperWeight.Weather.Service]}
# :disabled skips (unit tests inject their own Service with mocks)
config :paper_weight_host, weather_service: :enabled

# Spotify GenServer. Auth comes from env, read directly by
# PaperWeight.Spotify.Config.new/1 at service start (not via Application config):
#   SPOTIFY_CLIENT_ID / SPOTIFY_CLIENT_SECRET / SPOTIFY_REFRESH_TOKEN
# Defaults :disabled until a deployment has those secrets configured.
config :paper_weight_host, spotify_service: :disabled

# Feed GenServer. Source + auth come from env, read directly by
# PaperWeight.Feed.Config.from_env/1 at service start:
#   PAPER_WEIGHT_FEED_HANDLES / PAPER_WEIGHT_FEED_LIST_ID /
#   PAPER_WEIGHT_FEED_LIMIT / PAPER_WEIGHT_FEED_REFRESH_MS /
#   PAPER_WEIGHT_FEED_API_TOKEN
# Defaults :disabled until a deployment has handles/list + token configured.
config :paper_weight_host, feed_service: :disabled

# Photo GenServer. PaperWeight.Photo.Config has no env fallback of its own, so
# PaperWeight.Application reads PAPER_WEIGHT_PHOTO_LIBRARY_DIR directly and
# passes it as the :library_dir start option.
# Defaults :disabled until a deployment has a library directory configured.
config :paper_weight_host, photo_service: :disabled

# Bandit/WebSock gateway (PaperWeight.Gateway.*). Publishes the frozen envelope
# per enabled channel on connect and on generation advance; binds gateway_port.
# Disabled in test so `mix test` opens no port (see PaperWeight.Gateway.Socket
# moduledoc for the manual iex + websocat smoke path).
config :paper_weight_host, gateway_service: :enabled
config :paper_weight_host, gateway_port: 9138

# W3-F smoke profile: gateway: [stubs: :all]
# Env override: PAPER_WEIGHT_GATEWAY_STUBS=all → fixture adapters for every
# managed channel, real services forced off. See docs/architecture/wave-3-smoke.md.
config :paper_weight_host, gateway_stubs: :none

if config_env() == :test do
  config :paper_weight_host, weather_service: :disabled
  config :paper_weight_host, spotify_service: :disabled
  config :paper_weight_host, feed_service: :disabled
  config :paper_weight_host, photo_service: :disabled
  config :paper_weight_host, gateway_service: :disabled
  config :paper_weight_host, gateway_stubs: :none
end
