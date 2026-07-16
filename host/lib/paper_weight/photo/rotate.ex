defmodule PaperWeight.Photo.Rotate do
  @moduledoc """
  Pure photo rotation state: skip, keep-on-show pin, reprint deadline.

  Index is 0-based internally; snapshots expose 1-based N.
  """

  @type entry :: %{
          required(:id) => String.t(),
          required(:path) => String.t(),
          required(:caption) => String.t(),
          optional(atom()) => term()
        }

  @type t :: %{
          photos: [entry()],
          index: non_neg_integer(),
          kept: boolean(),
          interval_min: pos_integer(),
          deadline_ms: non_neg_integer()
        }

  @spec new([entry()], pos_integer(), non_neg_integer()) :: t()
  def new(photos, interval_min, now_ms)
      when is_list(photos) and is_integer(interval_min) and interval_min > 0 and
             is_integer(now_ms) and now_ms >= 0 do
    %{
      photos: photos,
      index: 0,
      kept: false,
      interval_min: interval_min,
      deadline_ms: now_ms + minutes_to_ms(interval_min)
    }
  end

  @doc """
  Replace the library list. Prefer keeping the same `id` when still present;
  otherwise clamp to 0. Resets the reprint timer and clears keep.
  """
  @spec rescan(t(), [entry()], non_neg_integer()) :: t()
  def rescan(state, photos, now_ms)
      when is_list(photos) and is_integer(now_ms) and now_ms >= 0 do
    current_id =
      case current(state) do
        nil -> nil
        entry -> entry.id
      end

    index =
      case current_id && Enum.find_index(photos, &(&1.id == current_id)) do
        nil -> 0
        i when is_integer(i) -> i
      end

    %{
      state
      | photos: photos,
        index: index,
        kept: false,
        deadline_ms: now_ms + minutes_to_ms(state.interval_min)
    }
  end

  @spec current(t()) :: entry() | nil
  def current(%{photos: []}), do: nil

  def current(%{photos: photos, index: index}) do
    Enum.at(photos, index)
  end

  @doc "1-based N for display; 0 when empty."
  @spec display_index(t()) :: non_neg_integer()
  def display_index(%{photos: []}), do: 0
  def display_index(%{index: index}), do: index + 1

  @spec total(t()) :: non_neg_integer()
  def total(%{photos: photos}), do: length(photos)

  @doc "Ceil remaining whole minutes until reprint deadline (0 when due)."
  @spec reprints_in_min(t(), non_neg_integer()) :: non_neg_integer()
  def reprints_in_min(%{deadline_ms: deadline_ms}, now_ms)
      when is_integer(now_ms) and now_ms >= 0 do
    remaining = deadline_ms - now_ms

    if remaining <= 0 do
      0
    else
      div(remaining + 60_000 - 1, 60_000)
    end
  end

  @doc "Advance one photo (wrap), clear keep, reset timer."
  @spec skip(t(), non_neg_integer()) :: t()
  def skip(%{photos: []} = state, _now_ms), do: state

  def skip(%{photos: photos, index: index} = state, now_ms)
      when is_integer(now_ms) and now_ms >= 0 do
    next = rem(index + 1, length(photos))

    %{
      state
      | index: next,
        kept: false,
        deadline_ms: now_ms + minutes_to_ms(state.interval_min)
    }
  end

  @doc "Toggle keep-on-show pin for the current photo."
  @spec keep(t()) :: t()
  def keep(%{photos: []} = state), do: state
  def keep(state), do: %{state | kept: not state.kept}

  @doc """
  Auto-advance when the deadline has passed and the photo is not kept.
  Idempotent when not due or when kept.
  """
  @spec tick(t(), non_neg_integer()) :: t()
  def tick(%{photos: []} = state, _now_ms), do: state
  def tick(%{kept: true} = state, _now_ms), do: state

  def tick(%{deadline_ms: deadline_ms} = state, now_ms)
      when is_integer(now_ms) and now_ms >= 0 do
    if now_ms >= deadline_ms do
      skip(state, now_ms)
    else
      state
    end
  end

  defp minutes_to_ms(min), do: min * 60_000
end
