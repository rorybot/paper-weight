defmodule PaperWeight.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {PaperWeight.Dither.Cache, name: PaperWeight.Dither.Cache}
      ] ++ weather_children()

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: PaperWeight.Supervisor
    )
  end

  defp weather_children do
    case Application.get_env(:paper_weight_host, :weather_service, :enabled) do
      :disabled ->
        []

      _ ->
        [
          {PaperWeight.Weather.Service,
           [
             name: PaperWeight.Weather.Service
           ]}
        ]
    end
  end
end
