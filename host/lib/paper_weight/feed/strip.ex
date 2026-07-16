defmodule PaperWeight.Feed.Strip do
  @moduledoc """
  Converts a provider's raw post map into the small display-safe feed shape.
  """

  alias PaperWeight.Feed.Accent

  @type stripped_post :: %{
          id: String.t(),
          handle: String.t(),
          body: String.t(),
          time_label: String.t()
        }

  @spec strip_post(map()) :: stripped_post()
  def strip_post(raw), do: strip_post(raw, DateTime.utc_now())

  @spec strip_post(map(), DateTime.t()) :: stripped_post()
  def strip_post(raw, now) do
    %{
      id: raw |> field(:id) |> stringify(),
      handle: raw |> field(:handle) |> Accent.normalize_handle(),
      body: raw |> body() |> plain_text(),
      time_label: time_label(raw, now)
    }
  end

  defp body(raw) do
    field(raw, :body) || field(raw, :text) || field(raw, :full_text) || ""
  end

  defp time_label(raw, now) do
    field(raw, :time_label) || format_age(field(raw, :created_at), now)
  end

  defp format_age(%DateTime{} = created_at, now), do: age_label(created_at, now)

  defp format_age(created_at, now) when is_binary(created_at) do
    case DateTime.from_iso8601(created_at) do
      {:ok, parsed, _offset} -> age_label(parsed, now)
      _ -> ""
    end
  end

  defp format_age(_created_at, _now), do: ""

  defp age_label(created_at, now) do
    seconds = max(DateTime.diff(now, created_at, :second), 0)

    cond do
      seconds < 60 -> "now"
      seconds < 3_600 -> "#{div(seconds, 60)}m"
      seconds < 86_400 -> "#{div(seconds, 3_600)}h"
      true -> "#{div(seconds, 86_400)}d"
    end
  end

  defp plain_text(value) do
    value
    |> stringify()
    |> String.replace(~r/<[^>]*>/u, " ")
    |> String.replace("&nbsp;", " ")
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace(<<0xE2, 0x80, 0x8B>>, "")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp field(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp stringify(nil), do: ""
  defp stringify(value), do: to_string(value)
end
