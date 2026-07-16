defmodule PaperWeight.Weather.Verdict do
  @moduledoc """
  Pure walk-verdict: one plain-spoken English sentence from weather inputs.

  Rules are ordered and deterministic — same inputs always yield the same line.
  """

  @type inputs :: %{
          required(:temp_f) => number(),
          required(:uv_index) => number(),
          optional(:precip) => boolean(),
          optional(:summary) => String.t()
        }

  @spec walk_verdict(inputs()) :: String.t()
  def walk_verdict(inputs) when is_map(inputs) do
    temp = Map.fetch!(inputs, :temp_f)
    uv = Map.fetch!(inputs, :uv_index)
    precip = precip?(inputs)
    grade = PaperWeight.Weather.Grade.grade_uv(uv)

    cond do
      precip and temp < 40 ->
        "Bundle up — cold and wet out there."

      precip ->
        "Take a jacket; rain's in the mix."

      grade == :extreme and temp >= 80 ->
        "Scorching sun — short walk, cover up."

      grade == :extreme ->
        "UV is brutal; shade or skip the long walk."

      grade == :high and temp >= 75 ->
        "Hot and bright — keep the walk short."

      grade == :high ->
        "UV is high; hat and sunscreen if you're out."

      temp >= 90 ->
        "Too hot for a long walk — stick to shade."

      temp <= 32 ->
        "Freezing out — walk if you must, dress warm."

      temp <= 45 ->
        "Chilly; a short walk is fine with a coat."

      true ->
        "Nice window for a walk."
    end
  end

  defp precip?(%{precip: true}), do: true
  defp precip?(%{precip: false}), do: false

  defp precip?(%{summary: summary}) when is_binary(summary) do
    s = String.downcase(summary)

    String.contains?(s, "rain") or
      String.contains?(s, "shower") or
      String.contains?(s, "storm") or
      String.contains?(s, "snow") or
      String.contains?(s, "sleet")
  end

  defp precip?(_), do: false
end
