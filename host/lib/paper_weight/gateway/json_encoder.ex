defmodule PaperWeight.Gateway.JsonEncoder do
  @moduledoc """
  Minimal dependency-free JSON encoder for outbound envelope frames. CI runs
  Elixir 1.17 (no built-in `JSON` module, added in 1.18), and this project
  does not carry a `Jason` dependency, so envelopes are encoded by hand.
  Handles the plain data shapes envelopes/payloads actually contain: maps,
  lists, strings, numbers, booleans, nil, and atoms (encoded as strings).
  """

  @spec encode!(term()) :: String.t()
  def encode!(nil), do: "null"
  def encode!(true), do: "true"
  def encode!(false), do: "false"
  def encode!(value) when is_integer(value) or is_float(value), do: to_string(value)
  def encode!(value) when is_binary(value), do: encode_string(value)
  def encode!(value) when is_atom(value), do: encode_string(Atom.to_string(value))

  def encode!(value) when is_list(value) do
    "[" <> Enum.map_join(value, ",", &encode!/1) <> "]"
  end

  def encode!(value) when is_map(value) do
    "{" <>
      Enum.map_join(value, ",", fn {k, v} -> encode_key(k) <> ":" <> encode!(v) end) <>
      "}"
  end

  defp encode_key(key) when is_atom(key), do: encode_string(Atom.to_string(key))
  defp encode_key(key) when is_binary(key), do: encode_string(key)

  defp encode_string(string) do
    escaped =
      string
      |> String.replace("\\", "\\\\")
      |> String.replace("\"", "\\\"")
      |> String.replace("\n", "\\n")

    "\"" <> escaped <> "\""
  end
end
