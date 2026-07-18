defmodule PaperWeight.Etymology.Snapshot do
  @moduledoc """
  Pure assembly of `EtymologySnapshotV1` maps (string keys for the JSON wire
  shape; see `src/device-ui/src/protocol/etymology.ts`).

  Turns a curated `Entry` into the day's snapshot: word metadata, the recursive
  `trace` (each node carrying its own `from` origin, `splits_into` branches, and
  `components`), and the trace `depth`.
  """

  alias PaperWeight.Etymology.{Entry, Origin}

  @type t :: %{String.t() => term()}

  @doc """
  Assemble a snapshot for `entry`.

  Options:

    * `:date` — the `Date.t()` the tree is for (drives `as_of` + `date_label`);
      defaults to `Date.utc_today/0`.
    * `:stale` — boolean, defaults to `false`.
  """
  @spec assemble(Entry.t(), keyword()) :: t()
  def assemble(%Entry{} = entry, opts \\ []) do
    date = Keyword.get(opts, :date) || Date.utc_today()
    stale = Keyword.get(opts, :stale, false)

    %{
      "as_of" => Date.to_iso8601(date),
      "date_label" => date_label(date),
      "stale" => stale,
      "source" => entry.source || "",
      "word" => %{
        "headword" => entry.headword,
        "language" => entry.language,
        "part_of_speech" => entry.part_of_speech,
        "gloss" => entry.gloss,
        "summary" => entry.summary || "",
        "cousins" => entry.cousins
      },
      "depth" => Origin.depth(entry.trace),
      "trace" => origin_to_map(entry.trace)
    }
  end

  @doc "Mark an existing snapshot as stale (last-good cache path)."
  @spec mark_stale(t()) :: t()
  def mark_stale(snapshot) when is_map(snapshot), do: Map.put(snapshot, "stale", true)

  @spec required_keys() :: [String.t()]
  def required_keys do
    ["as_of", "date_label", "stale", "source", "word", "depth", "trace"]
  end

  defp origin_to_map(%Origin{} = node) do
    %{
      "form" => node.form,
      "language" => node.language,
      "period" => node.period,
      "gloss" => node.gloss,
      "notes" => node.notes,
      "splits_into" => Enum.map(node.splits_into, &branch_to_map/1),
      "components" => Enum.map(node.components, &component_to_map/1),
      "root" => Origin.root?(node),
      "from" => from_to_map(node.from)
    }
  end

  defp from_to_map(nil), do: nil
  defp from_to_map(%Origin{} = node), do: origin_to_map(node)

  defp branch_to_map(%{form: form} = branch) do
    %{"form" => form, "note" => Map.get(branch, :note)}
  end

  defp component_to_map(%{form: form, gloss: gloss}) do
    %{"form" => form, "gloss" => gloss}
  end

  # "wed jul 15" — lowercase abbreviated weekday/month, matching mockup 2a.
  defp date_label(%Date{} = date) do
    date |> Calendar.strftime("%a %b %d") |> String.downcase()
  end
end
