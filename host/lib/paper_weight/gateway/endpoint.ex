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
