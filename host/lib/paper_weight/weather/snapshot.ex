defmodule PaperWeight.Weather.Snapshot do
  @moduledoc """
  Pure assembly of WeatherSnapshotV1 maps (string keys for JSON shape).
  """

  alias PaperWeight.Weather.{Grade, Nws, Verdict}

  @type day :: %{
          String.t() => term()
        }

  @type t :: %{
          String.t() => term()
        }

  @spec assemble(map()) :: t()
  def assemble(parts) do
    days = parts |> Map.get(:days, []) |> Nws.finalize_days()
    days5 = Enum.take(days, 5)
    days7 = pad_days(days, 7)

    current = Map.fetch!(parts, :current)
    uv_index = Map.fetch!(parts, :uv_index)
    grade = Grade.grade_uv(uv_index)
    stale = Map.get(parts, :stale, false)
    as_of = Map.get(parts, :as_of) || iso_now()
    location = Map.get(parts, :location_label) || "Unknown"
    hourly = Map.get(parts, :hourly_uv, [])

    verdict =
      Verdict.walk_verdict(%{
        temp_f: current.temp_f,
        uv_index: uv_index,
        summary: current.summary
      })

    %{
      "location_label" => location,
      "as_of" => as_of,
      "stale" => stale,
      "current" => %{
        "temp_f" => current.temp_f,
        "summary" => current.summary
      },
      "walk_verdict" => verdict,
      "uv" => %{
        "index" => uv_index,
        "grade" => Grade.to_string(grade)
      },
      "days5" => Enum.map(days5, &day_to_map/1),
      "days7" => Enum.map(days7, &day_to_map/1),
      "hourly_uv" => Enum.map(hourly, &hourly_to_map/1)
    }
  end

  @doc "Mark an existing snapshot as stale (last-good cache path)."
  @spec mark_stale(t()) :: t()
  def mark_stale(snapshot) when is_map(snapshot) do
    Map.put(snapshot, "stale", true)
  end

  @spec required_keys() :: [String.t()]
  def required_keys do
    [
      "location_label",
      "as_of",
      "stale",
      "current",
      "walk_verdict",
      "uv",
      "days5",
      "days7",
      "hourly_uv"
    ]
  end

  defp day_to_map(%{date: date, high_f: high, low_f: low, summary: summary}) do
    %{
      "date" => date,
      "high_f" => high,
      "low_f" => low,
      "summary" => summary
    }
  end

  defp hourly_to_map(%{hour_local: hour, index: index}) do
    %{"hour_local" => hour, "index" => index}
  end

  defp pad_days(days, n) when length(days) >= n, do: Enum.take(days, n)

  defp pad_days(days, n) do
    case List.last(days) do
      nil ->
        []

      last ->
        extras =
          1..(n - length(days))
          |> Enum.map(fn i ->
            %{
              date: shift_date(last.date, i),
              high_f: last.high_f,
              low_f: last.low_f,
              summary: last.summary
            }
          end)

        days ++ extras
    end
  end

  defp shift_date(<<y::binary-size(4), "-", m::binary-size(2), "-", d::binary-size(2)>>, days) do
    {:ok, date} = Date.from_iso8601("#{y}-#{m}-#{d}")
    date |> Date.add(days) |> Date.to_iso8601()
  end

  defp shift_date(other, _), do: other

  defp iso_now do
    DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
  end
end
