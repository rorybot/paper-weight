defmodule PaperWeight.Spotify.JsonLite do
  @moduledoc false
  # Minimal JSON object/array decoder for Spotify API fixtures when :json is unavailable.
  # Not a full JSON library — sufficient for known Spotify Web API response shapes.

  @spec decode(binary()) :: {:ok, term()} | {:error, term()}
  def decode(bin) when is_binary(bin) do
    case parse_value(String.trim(bin)) do
      {:ok, value, rest} ->
        if String.trim(rest) == "" do
          {:ok, value}
        else
          {:error, :trailing_garbage}
        end

      {:error, _} = err ->
        err
    end
  end

  defp parse_value(<<"null", rest::binary>>), do: {:ok, nil, rest}
  defp parse_value(<<"true", rest::binary>>), do: {:ok, true, rest}
  defp parse_value(<<"false", rest::binary>>), do: {:ok, false, rest}

  defp parse_value(<<?", rest::binary>>), do: parse_string(rest, [])

  defp parse_value(<<?[, rest::binary>>), do: parse_array(String.trim_leading(rest), [])

  defp parse_value(<<?{, rest::binary>>), do: parse_object(String.trim_leading(rest), %{})

  defp parse_value(<<c, _::binary>> = bin) when c in ?0..?9 or c == ?- do
    parse_number(bin)
  end

  defp parse_value(_), do: {:error, :unexpected_token}

  defp parse_string(<<?", rest::binary>>, acc) do
    {:ok, List.to_string(Enum.reverse(acc)), rest}
  end

  defp parse_string(<<?\\, ?", rest::binary>>, acc), do: parse_string(rest, [?" | acc])
  defp parse_string(<<?\\, ?\\, rest::binary>>, acc), do: parse_string(rest, [?\\ | acc])
  defp parse_string(<<?\\, ?/, rest::binary>>, acc), do: parse_string(rest, [?/ | acc])
  defp parse_string(<<?\\, ?n, rest::binary>>, acc), do: parse_string(rest, [?\n | acc])
  defp parse_string(<<?\\, ?r, rest::binary>>, acc), do: parse_string(rest, [?\r | acc])
  defp parse_string(<<?\\, ?t, rest::binary>>, acc), do: parse_string(rest, [?\t | acc])

  defp parse_string(<<?\\, ?u, a, b, c, d, rest::binary>>, acc) do
    code = List.to_integer([a, b, c, d], 16)
    parse_string(rest, [code | acc])
  end

  defp parse_string(<<ch::utf8, rest::binary>>, acc), do: parse_string(rest, [ch | acc])
  defp parse_string(<<>>, _), do: {:error, :unterminated_string}

  defp parse_array(<<?], rest::binary>>, acc), do: {:ok, Enum.reverse(acc), rest}

  defp parse_array(bin, acc) do
    with {:ok, value, rest} <- parse_value(String.trim_leading(bin)) do
      rest = String.trim_leading(rest)

      case rest do
        <<?,, rest2::binary>> -> parse_array(String.trim_leading(rest2), [value | acc])
        <<?], rest2::binary>> -> {:ok, Enum.reverse([value | acc]), rest2}
        _ -> {:error, :bad_array}
      end
    end
  end

  defp parse_object(<<?}, rest::binary>>, acc), do: {:ok, acc, rest}

  defp parse_object(bin, acc) do
    with {:ok, key, rest} <- parse_value(String.trim_leading(bin)),
         true <- is_binary(key),
         <<?:, rest2::binary>> <- String.trim_leading(rest),
         {:ok, value, rest3} <- parse_value(String.trim_leading(rest2)) do
      rest3 = String.trim_leading(rest3)
      acc = Map.put(acc, key, value)

      case rest3 do
        <<?,, rest4::binary>> -> parse_object(String.trim_leading(rest4), acc)
        <<?}, rest4::binary>> -> {:ok, acc, rest4}
        _ -> {:error, :bad_object}
      end
    else
      false -> {:error, :bad_object_key}
      _ -> {:error, :bad_object}
    end
  end

  defp parse_number(bin) do
    case Regex.run(~r/^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/, bin) do
      [num] ->
        rest = binary_part(bin, byte_size(num), byte_size(bin) - byte_size(num))

        value =
          if String.contains?(num, ".") or String.contains?(num, "e") or
               String.contains?(num, "E") do
            String.to_float(normalize_float(num))
          else
            String.to_integer(num)
          end

        {:ok, value, rest}

      _ ->
        {:error, :bad_number}
    end
  end

  defp normalize_float(num) do
    cond do
      String.contains?(num, ".") ->
        num

      String.contains?(num, "e") or String.contains?(num, "E") ->
        [base, exp] = String.split(num, ~r/[eE]/)
        "#{base}.0e#{exp}"

      true ->
        "#{num}.0"
    end
  end
end
