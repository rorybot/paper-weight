defmodule PaperWeight.Etymology.Selection do
  @moduledoc """
  Deterministic daily word selection (pure).

  Given the corpus and a calendar date, `pick/2` returns exactly one entry.
  The choice is stable for a given date (so the day's tree can be cached) and
  rotates as the date advances.
  """

  alias PaperWeight.Etymology.Entry

  @doc """
  Pick the entry for `date` from a non-empty list of `entries`.

  Uses the Gregorian day number modulo the corpus size, so the same date always
  yields the same entry and consecutive days step through the corpus.
  """
  @spec pick([Entry.t(), ...], Date.t()) :: Entry.t()
  def pick([_ | _] = entries, %Date{} = date) do
    Enum.at(entries, index_for(date, length(entries)))
  end

  @doc "Zero-based corpus index chosen for `date` given a corpus of `count` entries."
  @spec index_for(Date.t(), pos_integer()) :: non_neg_integer()
  def index_for(%Date{} = date, count) when is_integer(count) and count > 0 do
    day_number = :calendar.date_to_gregorian_days(Date.to_erl(date))
    Integer.mod(day_number, count)
  end
end
