defmodule PaperWeight.Photo.Config do
  @moduledoc """
  Photo service configuration.

  `library_dir` is a local flat directory of dropped images.
  `reprint_interval_min` drives the "reprints in X min" countdown.
  """

  @type t :: %{
          library_dir: String.t() | nil,
          reprint_interval_min: pos_integer(),
          extensions: MapSet.t(String.t()),
          source_label: String.t() | nil,
          tick_ms: pos_integer() | :infinity
        }

  @default_interval_min 5
  @default_tick_ms 30_000

  @default_extensions MapSet.new([
                        ".jpg",
                        ".jpeg",
                        ".png",
                        ".webp",
                        ".gif",
                        ".bmp",
                        ".pbm",
                        ".pgm"
                      ])

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    extensions =
      case Keyword.get(opts, :extensions) do
        nil ->
          @default_extensions

        list when is_list(list) ->
          list
          |> Enum.map(&normalize_ext/1)
          |> MapSet.new()
      end

    %{
      library_dir: Keyword.get(opts, :library_dir),
      reprint_interval_min: Keyword.get(opts, :reprint_interval_min, @default_interval_min),
      extensions: extensions,
      source_label: Keyword.get(opts, :source_label),
      tick_ms: Keyword.get(opts, :tick_ms, @default_tick_ms)
    }
  end

  @spec image_extension?(t(), String.t()) :: boolean()
  def image_extension?(config, ext) when is_binary(ext) do
    MapSet.member?(config.extensions, normalize_ext(ext))
  end

  defp normalize_ext(ext) do
    ext
    |> to_string()
    |> String.downcase()
    |> then(fn
      <<".", _::binary>> = e -> e
      e -> "." <> e
    end)
  end
end
