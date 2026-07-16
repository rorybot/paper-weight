defmodule PaperWeight.Feed.Config do
  @moduledoc """
  Runtime configuration for the read-only feed snapshot service.

  Credentials are read only from the environment and are never included in a
  snapshot. A list id may be used instead of explicit handles.
  """

  alias PaperWeight.Feed.Fetch.XClient

  @default_limit 20
  @default_refresh_ms :timer.minutes(5)

  @enforce_keys [:client]
  defstruct handles: [],
            list_id: nil,
            limit: @default_limit,
            refresh_ms: @default_refresh_ms,
            api_token: nil,
            client: XClient

  @type t :: %__MODULE__{
          handles: [String.t()],
          list_id: String.t() | nil,
          limit: pos_integer(),
          refresh_ms: pos_integer(),
          api_token: String.t() | nil,
          client: module()
        }

  @spec new(keyword()) :: t()
  def new(options \\ []) do
    %__MODULE__{
      handles: options |> Keyword.get(:handles, []) |> normalize_handles(),
      list_id: options |> Keyword.get(:list_id) |> blank_to_nil(),
      limit: positive_integer(Keyword.get(options, :limit), @default_limit),
      refresh_ms: positive_integer(Keyword.get(options, :refresh_ms), @default_refresh_ms),
      api_token: options |> Keyword.get(:api_token) |> blank_to_nil(),
      client: Keyword.get(options, :client, XClient)
    }
  end

  @spec from_env((String.t() -> String.t() | nil)) :: t()
  def from_env(get_env \\ &System.get_env/1) do
    new(
      handles: split_handles(get_env.("PAPER_WEIGHT_FEED_HANDLES")),
      list_id: get_env.("PAPER_WEIGHT_FEED_LIST_ID"),
      limit: get_env.("PAPER_WEIGHT_FEED_LIMIT"),
      refresh_ms: get_env.("PAPER_WEIGHT_FEED_REFRESH_MS"),
      api_token: get_env.("PAPER_WEIGHT_FEED_API_TOKEN")
    )
  end

  defp normalize_handles(handles) do
    handles
    |> List.wrap()
    |> Enum.map(&PaperWeight.Feed.Accent.normalize_handle/1)
    |> Enum.reject(&(&1 == "@"))
    |> Enum.uniq()
  end

  defp split_handles(nil), do: []

  defp split_handles(value) do
    String.split(value, ",", trim: true)
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case value |> to_string() |> String.trim() do
      "" -> nil
      normalized -> normalized
    end
  end

  defp positive_integer(nil, default), do: default
  defp positive_integer(value, _default) when is_integer(value) and value > 0, do: value

  defp positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} when parsed > 0 -> parsed
      _ -> default
    end
  end

  defp positive_integer(_value, default), do: default
end
