defmodule PaperWeight.Etymology.Entry do
  @moduledoc """
  A curated corpus entry: the day's word (display metadata) plus its recursive
  origin `trace` (an `PaperWeight.Etymology.Origin` node) and a `source` label.

  This is the shape a "Wiktionary-style source" yields — pure data. A live
  source would build the same struct from fetched pages; the `Corpus` module
  ships a hand-curated set for now.
  """

  alias PaperWeight.Etymology.Origin

  @enforce_keys [:headword, :language, :part_of_speech, :gloss, :trace]
  defstruct headword: nil,
            language: nil,
            part_of_speech: nil,
            gloss: nil,
            summary: nil,
            cousins: [],
            source: nil,
            trace: nil

  @type t :: %__MODULE__{
          headword: String.t(),
          language: String.t(),
          part_of_speech: String.t(),
          gloss: String.t(),
          summary: String.t() | nil,
          cousins: [String.t()],
          source: String.t() | nil,
          trace: Origin.t()
        }

  @doc "Build an entry from a keyword list or map of attrs."
  @spec new(Enum.t()) :: t()
  def new(attrs), do: struct!(__MODULE__, attrs)

  @doc "Depth of the entry's origin trace (see `Origin.depth/1`)."
  @spec depth(t()) :: non_neg_integer()
  def depth(%__MODULE__{trace: trace}), do: Origin.depth(trace)
end
