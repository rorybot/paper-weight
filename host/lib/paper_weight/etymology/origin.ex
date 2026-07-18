defmodule PaperWeight.Etymology.Origin do
  @moduledoc """
  Recursive origin-trace node (pure).

  Each node is one stage in a word's history: its `form` at that stage, the
  `language`/`period` it belongs to, a short `gloss`, and a link (`from`) to the
  *earlier* stage it descended from. Walking `from` repeatedly climbs toward the
  root; a node with `from: nil` is the terminal — bedrock, no earlier attested
  form (see `root?/1`).

  Two extras hang off a node for the drill-down views (mockups 2b/2c):

    * `splits_into` — later words that branched off this stage ("SPLITS INTO").
    * `components` — morphological breakdown of a compound root (e.g.
      `trēs` + `pālus`), rendered under a terminal root.

  Newest → oldest. The day's word is the top node; `ladder/1` flattens the
  spine for the depth-0 trace view.
  """

  @enforce_keys [:form, :language, :gloss]
  defstruct form: nil,
            language: nil,
            period: nil,
            gloss: nil,
            notes: nil,
            splits_into: [],
            components: [],
            from: nil

  @type branch :: %{form: String.t(), note: String.t() | nil}
  @type component :: %{form: String.t(), gloss: String.t()}

  @type t :: %__MODULE__{
          form: String.t(),
          language: String.t(),
          period: String.t() | nil,
          gloss: String.t(),
          notes: String.t() | nil,
          splits_into: [branch()],
          components: [component()],
          from: t() | nil
        }

  @doc "Build a node from a keyword list or map of attrs."
  @spec new(Enum.t()) :: t()
  def new(attrs), do: struct!(__MODULE__, attrs)

  @doc """
  Depth = number of `from` hops from this node to the terminal root.

  A lone root is depth 0; the `travel` spine (travel → travailen → travailler →
  trepālium) is depth 3.
  """
  @spec depth(t()) :: non_neg_integer()
  def depth(%__MODULE__{from: nil}), do: 0
  def depth(%__MODULE__{from: %__MODULE__{} = from}), do: 1 + depth(from)

  @doc "Terminal root of the trace — the last node reachable via `from`."
  @spec root(t()) :: t()
  def root(%__MODULE__{from: nil} = node), do: node
  def root(%__MODULE__{from: %__MODULE__{} = from}), do: root(from)

  @doc "True when the node is a terminal root (no earlier attested form)."
  @spec root?(t()) :: boolean()
  def root?(%__MODULE__{from: nil}), do: true
  def root?(%__MODULE__{}), do: false

  @doc """
  Flatten the trace spine newest → oldest into a flat list of nodes (the ladder
  view). `from` links are kept intact on each returned node.
  """
  @spec ladder(t()) :: [t()]
  def ladder(%__MODULE__{} = node), do: do_ladder(node, [])

  defp do_ladder(%__MODULE__{from: nil} = node, acc), do: Enum.reverse([node | acc])
  defp do_ladder(%__MODULE__{from: from} = node, acc), do: do_ladder(from, [node | acc])
end
