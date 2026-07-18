defmodule PaperWeight.Protocol.Envelope do
  @moduledoc """
  Frozen host↔device envelope v1. Domain agents must not change this module.

  See `docs/architecture/host-device-protocol-v1.md`.
  """

  @type channel ::
          :now_playing
          | :weather
          | :feed
          | :photo
          | :etymology
          | :playlist
          | :system

  @type t :: %{
          required(:v) => 1,
          required(:ts) => integer(),
          required(:channel) => channel(),
          required(:gen) => non_neg_integer(),
          required(:payload) => term()
        }

  @spec wrap(channel(), non_neg_integer(), term(), integer()) :: t()
  def wrap(channel, gen, payload, ts \\ System.system_time(:millisecond))
      when is_integer(gen) and gen >= 0 and is_integer(ts) do
    %{v: 1, ts: ts, channel: channel, gen: gen, payload: payload}
  end
end
