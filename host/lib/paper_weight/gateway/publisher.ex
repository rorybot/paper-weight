defmodule PaperWeight.Gateway.Publisher do
  @moduledoc """
  Pure assembly of the per-channel envelope batch pushed on connect and on
  generation advance. Takes already-fetched channel inputs (see
  `PaperWeight.Gateway.Socket` for the impure edge that collects them) so this
  module can be tested against plain data with no GenServers involved.

  Playlist is a normal channel input (W3-G) sourced from `Spotify.Service`
  playlists/generation — not a hardcoded stub.
  """

  alias PaperWeight.Protocol.Envelope

  @type channel_input :: {:ok, term(), non_neg_integer()} | :disabled | {:error, term()}

  @type inputs :: %{
          optional(:weather) => channel_input(),
          optional(:spotify) => channel_input(),
          optional(:feed) => channel_input(),
          optional(:photo) => channel_input(),
          optional(:playlist) => channel_input()
        }

  @spec envelopes(inputs(), integer()) :: [Envelope.t()]
  def envelopes(inputs, ts \\ System.system_time(:millisecond)) do
    [
      channel_envelope(:weather, Map.get(inputs, :weather, :disabled), ts),
      channel_envelope(:now_playing, Map.get(inputs, :spotify, :disabled), ts),
      channel_envelope(:feed, Map.get(inputs, :feed, :disabled), ts),
      channel_envelope(:photo, Map.get(inputs, :photo, :disabled), ts),
      channel_envelope(:playlist, Map.get(inputs, :playlist, :disabled), ts)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp channel_envelope(_channel, :disabled, _ts), do: nil
  defp channel_envelope(_channel, {:error, _reason}, _ts), do: nil

  defp channel_envelope(channel, {:ok, payload, gen}, ts) do
    Envelope.wrap(channel, gen, payload, ts)
  end
end
