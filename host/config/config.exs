import Config

# Weather GenServer under PaperWeight.Application.
# :enabled starts {PaperWeight.Weather.Service, [name: PaperWeight.Weather.Service]}
# :disabled skips (unit tests inject their own Service with mocks)
config :paper_weight_host, weather_service: :enabled

if config_env() == :test do
  config :paper_weight_host, weather_service: :disabled
end
