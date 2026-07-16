defmodule PaperWeight.Spotify.Snapshot do
  @moduledoc """
  Pure assembly of NowPlayingSnapshotV1 maps (string keys for JSON shape).
  See `src/device-ui/src/protocol/now_playing.ts`.
  """

  @type t :: %{String.t() => term()}

  @spec assemble(map()) :: t()
  def assemble(parts) do
    track = Map.get(parts, :track)
    queue = Map.get(parts, :queue, [])
    volume_level = Map.get(parts, :volume_level, 0)
    stale = Map.get(parts, :stale, false)
    as_of = Map.get(parts, :as_of) || iso_now()
    art_pbm_base64 = Map.get(parts, :art_pbm_base64)

    %{
      "as_of" => as_of,
      "stale" => stale,
      "track" => track_to_map(track, art_pbm_base64),
      "queue" => Enum.map(queue, &queue_item_to_map/1),
      "volume" => %{"level" => volume_level},
      "lyrics" => nil
    }
  end

  @doc "Mark an existing snapshot as stale (last-good cache path)."
  @spec mark_stale(t()) :: t()
  def mark_stale(snapshot) when is_map(snapshot) do
    Map.put(snapshot, "stale", true)
  end

  @spec required_keys() :: [String.t()]
  def required_keys do
    ["as_of", "stale", "track", "queue", "volume", "lyrics"]
  end

  defp track_to_map(nil, _art), do: nil
  defp track_to_map(:none, _art), do: nil

  defp track_to_map(track, art_pbm_base64) do
    %{
      "title" => track.title,
      "artist" => track.artist,
      "album" => track.album,
      "art_pbm_base64" => art_pbm_base64,
      "duration_ms" => track.duration_ms,
      "progress_ms" => track.progress_ms
    }
  end

  defp queue_item_to_map(%{title: title, artist: artist}) do
    %{"title" => title, "artist" => artist}
  end

  defp iso_now do
    DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
  end
end
