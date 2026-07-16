defmodule PaperWeight.Weather.Grade do
  @moduledoc """
  Pure UV index → grade mapping (locked W1 contract).

  | Grade    | Rule            |
  |----------|-----------------|
  | extreme  | index ≥ 8       |
  | high     | 6 ≤ index < 8   |
  | low      | index < 6       |
  """

  @type grade :: :extreme | :high | :low

  @spec grade_uv(number()) :: grade()
  def grade_uv(index) when is_number(index) do
    cond do
      index >= 8 -> :extreme
      index >= 6 -> :high
      true -> :low
    end
  end

  @doc "JSON/protocol string form of grade."
  @spec to_string(grade()) :: String.t()
  def to_string(:extreme), do: "extreme"
  def to_string(:high), do: "high"
  def to_string(:low), do: "low"
end
