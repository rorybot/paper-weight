defmodule PaperWeight.Etymology.Corpus do
  @moduledoc """
  Hand-curated "Wiktionary-style" source of day's-word entries (pure).

  Stands in for a live source until an etymology fetch card exists. Each entry
  carries a full recursive origin trace. `entries/0` is the default corpus the
  daily selection rotates through; the `travel` entry is the seed used by the
  design mockups (2a/2b/2c) and the acceptance fixture.
  """

  alias PaperWeight.Etymology.{Entry, Origin}

  @source "etymonline snapshot"

  @doc "All curated entries, in a stable order (daily selection rotates over these)."
  @spec entries() :: [Entry.t(), ...]
  def entries, do: [travel(), salary(), clue()]

  @doc "The `travel` entry — depth-3 trace ending at the Latin root `trepālium`."
  @spec travel() :: Entry.t()
  def travel do
    Entry.new(
      headword: "travel",
      language: "modern english",
      part_of_speech: "verb",
      gloss: "to make a journey",
      summary: "its root means torture. journeys used to be agony — the word never forgot.",
      cousins: ["travail", "travolator"],
      source: @source,
      trace: travel_trace()
    )
  end

  defp travel_trace do
    trepalium =
      Origin.new(
        form: "trepālium",
        language: "late latin",
        period: "c.400",
        gloss: "a frame of three stakes used for torture",
        notes: ~s("three" + "stake" → you turned a wheel to reach a torture device),
        components: [
          %{form: "trēs", gloss: "three"},
          %{form: "pālus", gloss: "stake"}
        ]
      )

    travailler =
      Origin.new(
        form: "travailler",
        language: "old french",
        period: "c.1200",
        gloss: "to labour, to suffer",
        notes:
          "Borrowed into Middle English as travailen. Because medieval journeys were long " <>
            "and dangerous, \"to labour/suffer\" drifted into \"to journey\" — and English kept " <>
            "travail (hardship) and travel (the trip) as two words from this one.",
        splits_into: [
          %{form: "travel", note: "en"},
          %{form: "travail", note: "en/fr"}
        ],
        from: trepalium
      )

    travailen =
      Origin.new(
        form: "travailen",
        language: "middle english",
        period: "c.1375",
        gloss: "to toil, to journey",
        from: travailler
      )

    Origin.new(
      form: "travel",
      language: "modern english",
      period: "now",
      gloss: "to journey",
      from: travailen
    )
  end

  @doc "The `salary` entry — English → Latin `sal` (salt) root."
  @spec salary() :: Entry.t()
  def salary do
    sal =
      Origin.new(
        form: "sāl",
        language: "latin",
        period: "latin",
        gloss: "salt",
        notes: "soldiers were once paid an allowance to buy salt.",
        components: [%{form: "sāl", gloss: "salt"}]
      )

    salarium =
      Origin.new(
        form: "salārium",
        language: "latin",
        period: "c.100",
        gloss: "a soldier's salt-money",
        splits_into: [%{form: "salary", note: "en"}],
        from: sal
      )

    trace =
      Origin.new(
        form: "salary",
        language: "modern english",
        period: "now",
        gloss: "fixed regular pay",
        from: salarium
      )

    Entry.new(
      headword: "salary",
      language: "modern english",
      part_of_speech: "noun",
      gloss: "fixed regular pay",
      summary: "you were, quite literally, worth your salt.",
      cousins: ["saline", "salad"],
      source: @source,
      trace: trace
    )
  end

  @doc "The `clue` entry — English → a ball of thread (Theseus in the labyrinth)."
  @spec clue() :: Entry.t()
  def clue do
    cliewen =
      Origin.new(
        form: "cliewen",
        language: "old english",
        period: "c.900",
        gloss: "a ball of thread",
        notes: "Theseus unspooled a ball of thread to find his way out of the labyrinth.",
        components: [%{form: "cliewen", gloss: "ball, sphere"}]
      )

    clewe =
      Origin.new(
        form: "clewe",
        language: "middle english",
        period: "c.1400",
        gloss: "ball of thread; a guide out of a maze",
        splits_into: [%{form: "clue", note: "en"}],
        from: cliewen
      )

    trace =
      Origin.new(
        form: "clue",
        language: "modern english",
        period: "now",
        gloss: "a hint that leads to a solution",
        from: clewe
      )

    Entry.new(
      headword: "clue",
      language: "modern english",
      part_of_speech: "noun",
      gloss: "a hint that leads to a solution",
      summary: "a clue was the thread that led you out — solving is just finding the way back.",
      cousins: ["clew"],
      source: @source,
      trace: trace
    )
  end
end
