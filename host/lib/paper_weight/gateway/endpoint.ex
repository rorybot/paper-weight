defmodule PaperWeight.Gateway.Endpoint do
  @moduledoc """
  Plug entry point for the gateway WebSocket. Upgrades every request to
  `PaperWeight.Gateway.Socket`, seeded with the `adapters` map configured at
  supervisor start (see `PaperWeight.Application`).

  ## Manual smoke test

      iex -S mix
      # in another shell:
      websocat ws://localhost:9138/

  Expect one JSON envelope per enabled channel immediately on connect.

  ## Fixture smoke (W3-F)

      PAPER_WEIGHT_GATEWAY_STUBS=all mix run --no-halt
      # device UI: cd src/device-ui && npm run dev:live

  See `docs/architecture/wave-3-smoke.md`.
  """

  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, opts) do
    adapters = Keyword.fetch!(opts, :adapters)
    WebSockAdapter.upgrade(conn, PaperWeight.Gateway.Socket, adapters, timeout: 60_000)
  end
end
