defmodule PaperWeight.Photo.Snapshot do
  @moduledoc """
  Pure assembly of PhotoSnapshotV1 maps (string keys for JSON shape).
  """

  alias PaperWeight.Photo.Rotate

  @type t :: %{String.t() => term()}

  @spec assemble(map()) :: t()
  def assemble(parts) do
    state = Map.fetch!(parts, :state)
    now_ms = Map.fetch!(parts, :now_ms)
    stale = Map.get(parts, :stale, false)
    as_of = Map.get(parts, :as_of) || iso_now()
    source = Map.get(parts, :source) || "local library"
    art = Map.get(parts, :art_pbm_base64)

    entry = Rotate.current(state)
    empty? = entry == nil

    %{
      "as_of" => as_of,
      "stale" => stale,
      "source" => source,
      "empty" => empty?,
      "index" => Rotate.display_index(state),
      "total" => Rotate.total(state),
      "caption" => if(entry, do: entry.caption, else: ""),
      "id" => if(entry, do: entry.id, else: nil),
      "path" => if(entry, do: entry.path, else: nil),
      "kept" => state.kept,
      "reprints_in_min" => Rotate.reprints_in_min(state, now_ms),
      "reprint_interval_min" => state.interval_min,
      "art_pbm_base64" => art
    }
  end

  @doc "Mark an existing snapshot as stale (last-good cache path)."
  @spec mark_stale(t()) :: t()
  def mark_stale(snapshot) when is_map(snapshot) do
    Map.put(snapshot, "stale", true)
  end

  @spec required_keys() :: [String.t()]
  def required_keys do
    [
      "as_of",
      "stale",
      "source",
      "empty",
      "index",
      "total",
      "caption",
      "id",
      "path",
      "kept",
      "reprints_in_min",
      "reprint_interval_min",
      "art_pbm_base64"
    ]
  end

  defp iso_now do
    DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
  end
end
