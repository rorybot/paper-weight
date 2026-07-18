defmodule PaperWeight.Gateway.PlaylistStub do
  @moduledoc """
  Stub `playlist` channel snapshot until W3-G wires a real playlist service.
  Shape matches `PlaylistSnapshotV1` (see `host-device-protocol-v1.md`).
  """

  alias PaperWeight.Protocol.Envelope

  @gen 1

  @spec envelope(integer()) :: Envelope.t()
  def envelope(ts \\ System.system_time(:millisecond)) do
    Envelope.wrap(:playlist, @gen, payload(), ts)
  end

  defp payload do
    %{
      as_of: DateTime.utc_now() |> DateTime.to_iso8601(),
      stale: false,
      playlists: []
    }
  end
end
