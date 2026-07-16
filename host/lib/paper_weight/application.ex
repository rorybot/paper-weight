defmodule PaperWeight.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {PaperWeight.Dither.Cache, name: PaperWeight.Dither.Cache}
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: PaperWeight.Supervisor
    )
  end
end
