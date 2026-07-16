defmodule PaperWeight.Protocol.EnvelopeTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Protocol.Envelope

  test "wrap/4 builds v1 envelope" do
    env = Envelope.wrap(:weather, 7, %{ok: true}, 1_700_000_000_000)

    assert env == %{
             v: 1,
             ts: 1_700_000_000_000,
             channel: :weather,
             gen: 7,
             payload: %{ok: true}
           }
  end
end
