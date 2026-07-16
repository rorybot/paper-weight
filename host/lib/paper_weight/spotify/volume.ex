defmodule PaperWeight.Spotify.Volume do
  @moduledoc """
  Pure volume math. Level is always clamped to 0..100.

  No play/pause here or anywhere in this lane — volume only.
  """

  @min 0
  @max 100

  @spec clamp(integer()) :: 0..100
  def clamp(level) when is_integer(level) do
    level |> max(@min) |> min(@max)
  end

  @spec apply_delta(integer(), integer()) :: 0..100
  def apply_delta(current_level, delta)
      when is_integer(current_level) and is_integer(delta) do
    clamp(current_level + delta)
  end
end
