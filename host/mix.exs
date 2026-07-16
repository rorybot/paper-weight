defmodule PaperWeightHost.MixProject do
  use Mix.Project

  def project do
    [
      app: :paper_weight_host,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  def application do
    [
      extra_applications: [:crypto, :logger],
      mod: {PaperWeight.Application, []}
    ]
  end
end
