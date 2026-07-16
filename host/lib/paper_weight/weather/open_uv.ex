defmodule PaperWeight.Weather.OpenUv do
  @moduledoc """
  Pure-ish parsers for OpenUV JSON responses.
  """

  @type uv_now :: %{index: number()}
  @type hourly :: %{hour_local: String.t(), index: number()}

  @spec parse_uv(map()) :: {:ok, uv_now()} | {:error, term()}
  def parse_uv(%{"result" => %{"uv" => uv}}) when is_number(uv) do
    {:ok, %{index: uv}}
  end

  def parse_uv(%{"result" => %{"uv" => uv}}) when is_binary(uv) do
    case Float.parse(uv) do
      {n, _} -> {:ok, %{index: n}}
      :error -> {:error, :invalid_uv}
    end
  end

  def parse_uv(_), do: {:error, :invalid_uv_response}

  @spec parse_forecast(map()) :: {:ok, [hourly()]} | {:error, term()}
  def parse_forecast(%{"result" => results}) when is_list(results) do
    hours =
      results
      |> Enum.flat_map(&hourly_from_entry/1)
      |> Enum.take(24)

    {:ok, hours}
  end

  def parse_forecast(_), do: {:error, :invalid_forecast_response}

  defp hourly_from_entry(%{"uv" => uv, "uv_time" => time})
       when is_number(uv) and is_binary(time) do
    [%{hour_local: hour_local(time), index: uv}]
  end

  defp hourly_from_entry(%{"uv" => uv, "uv_time" => time})
       when is_binary(uv) and is_binary(time) do
    case Float.parse(uv) do
      {n, _} -> [%{hour_local: hour_local(time), index: n}]
      :error -> []
    end
  end

  defp hourly_from_entry(_), do: []

  defp hour_local(iso) do
    case String.split(iso, "T", parts: 2) do
      [_date, rest] ->
        rest
        |> String.split(["+", "Z", "-"], parts: 2)
        |> List.first()
        |> String.slice(0, 5)

      _ ->
        iso
    end
  end
end
