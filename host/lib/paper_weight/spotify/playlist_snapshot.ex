defmodule PaperWeight.Spotify.PlaylistSnapshot do
  @moduledoc """
  Pure assembly of PlaylistSnapshotV1 maps (atom keys for JSON shape).

  Matches `src/device-ui/src/protocol/playlist.ts` and the Elixir mirror in
  `docs/architecture/host-device-protocol-v1.md`. Cover art is optional —
  `cover_pbm_base64` may be `nil` (CSS hatch on device) when no dithered Image
  is available (same pattern as N1 album art).
  """

  @type item :: %{
          id: String.t(),
          name: String.t(),
          cover_pbm_base64: String.t() | nil
        }

  @type t :: %{
          as_of: String.t(),
          stale: boolean(),
          playlists: [item()]
        }

  @spec assemble(map()) :: t()
  def assemble(parts) when is_map(parts) do
    playlists = Map.get(parts, :playlists, [])
    stale = Map.get(parts, :stale, false)
    as_of = Map.get(parts, :as_of) || iso_now()

    %{
      as_of: as_of,
      stale: stale,
      playlists: Enum.map(playlists, &item_to_map/1)
    }
  end

  @doc "Mark an existing playlist snapshot as stale (last-good cache path)."
  @spec mark_stale(t()) :: t()
  def mark_stale(snapshot) when is_map(snapshot) do
    Map.put(snapshot, :stale, true)
  end

  @spec required_keys() :: [atom()]
  def required_keys, do: [:as_of, :stale, :playlists]

  defp item_to_map(%{id: id, name: name} = item) do
    %{
      id: id,
      name: name,
      cover_pbm_base64: Map.get(item, :cover_pbm_base64)
    }
  end

  defp item_to_map(%{"id" => id, "name" => name} = item) do
    %{
      id: id,
      name: name,
      cover_pbm_base64: Map.get(item, "cover_pbm_base64")
    }
  end

  defp iso_now do
    DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
  end
end
