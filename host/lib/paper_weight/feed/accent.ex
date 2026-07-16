defmodule PaperWeight.Feed.Accent do
  @moduledoc """
  Assigns a deterministic display accent to each feed handle.
  """

  @palette [
    "#ff6b35",
    "#f7c948",
    "#4ecdc4",
    "#5b8def",
    "#c77dff",
    "#ff7aa2"
  ]

  @spec assign_accents([String.t()]) :: %{String.t() => String.t()}
  def assign_accents(handles) do
    handles
    |> Enum.map(&normalize_handle/1)
    |> Enum.reject(&(&1 == "@"))
    |> Enum.uniq()
    |> Map.new(&{&1, accent_for(&1)})
  end

  @spec accent_for(String.t()) :: String.t()
  def accent_for(handle) do
    normalized = normalize_handle(handle)
    index = normalized |> stable_hash() |> rem(length(@palette))
    Enum.at(@palette, index)
  end

  @spec normalize_handle(String.t()) :: String.t()
  def normalize_handle(handle) do
    normalized =
      handle
      |> to_string()
      |> String.trim()
      |> String.trim_leading("@")
      |> String.downcase()

    "@" <> normalized
  end

  defp stable_hash(value) do
    value
    |> String.to_charlist()
    |> Enum.reduce(5_381, fn character, hash ->
      rem(hash * 33 + character, 4_294_967_296)
    end)
  end
end
