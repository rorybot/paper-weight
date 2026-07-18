defmodule PaperWeight.Gateway.JsonEncoderTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Gateway.JsonEncoder

  test "encodes scalars, atoms, strings with escaping, lists, and nested maps" do
    assert JsonEncoder.encode!(nil) == "null"
    assert JsonEncoder.encode!(true) == "true"
    assert JsonEncoder.encode!(42) == "42"
    assert JsonEncoder.encode!(:weather) == "\"weather\""
    assert JsonEncoder.encode!("he said \"hi\"\\bye") == "\"he said \\\"hi\\\"\\\\bye\""
    assert JsonEncoder.encode!([1, "a", nil]) == "[1,\"a\",null]"

    encoded = JsonEncoder.encode!(%{channel: :weather, gen: 1, payload: %{"temp" => 70}})
    assert encoded =~ ~s("channel":"weather")
    assert encoded =~ ~s("gen":1)
    assert encoded =~ ~s("payload":{"temp":70})
  end
end
