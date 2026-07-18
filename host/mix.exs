defmodule PaperWeightHost.MixProject do
  use Mix.Project

  def project do
    [
      app: :paper_weight_host,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:crypto, :logger] ++ optional_http_apps(),
      mod: {PaperWeight.Application, []}
    ]
  end

  # Locked WS transport deps for the wave-3 host gateway. Nothing starts Bandit
  # yet (W3-C wires the listener) — this wave only adds the compiled deps.
  defp deps do
    [
      {:bandit, "~> 1.5"},
      {:websock_adapter, "~> 0.5"},
      {:plug, "~> 1.16"}
    ]
  end

  # Live NWS/OpenUV use :httpc. Include when OTP ships them; skip on minimal installs.
  defp optional_http_apps do
    case :code.lib_dir(:inets) do
      {:error, _} -> []
      _ -> [:inets, :ssl]
    end
  end
end
