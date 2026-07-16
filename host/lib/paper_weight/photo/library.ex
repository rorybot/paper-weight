defmodule PaperWeight.Photo.Library do
  @moduledoc """
  Local photo library ingest: flat-dir scan, ordered entries, caption sidecars.

  Caption rule: optional `<basename>.txt` beside the image; else humanized basename.
  """

  alias PaperWeight.Photo.Config

  @type entry :: %{
          id: String.t(),
          path: String.t(),
          caption: String.t(),
          basename: String.t()
        }

  @spec scan(Config.t() | keyword()) :: [entry()]
  def scan(opts) when is_list(opts), do: scan(Config.new(opts))

  def scan(%{} = config) do
    dir = config.library_dir

    cond do
      is_nil(dir) or dir == "" ->
        []

      not File.dir?(dir) ->
        []

      true ->
        dir
        |> File.ls!()
        |> Enum.filter(&image_file?(config, dir, &1))
        |> Enum.map(&to_entry(dir, &1))
        |> Enum.sort_by(&sort_key/1)
    end
  end

  @doc "Humanize a file stem for captions: `beach_day` → `beach day`."
  @spec humanize_basename(String.t()) :: String.t()
  def humanize_basename(name) when is_binary(name) do
    name
    |> Path.rootname()
    |> String.replace(~r/[_\-]+/u, " ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp image_file?(config, dir, name) do
    path = Path.join(dir, name)
    File.regular?(path) and Config.image_extension?(config, Path.extname(name))
  end

  defp to_entry(dir, name) do
    path = Path.join(dir, name) |> Path.expand()
    stem = Path.rootname(name)
    id = stem

    %{
      id: id,
      path: path,
      basename: name,
      caption: caption_for(dir, stem)
    }
  end

  defp caption_for(dir, stem) do
    sidecar = Path.join(dir, stem <> ".txt")

    if File.regular?(sidecar) do
      sidecar
      |> File.read!()
      |> String.trim()
      |> case do
        "" -> humanize_basename(stem)
        text -> first_line(text)
      end
    else
      humanize_basename(stem)
    end
  end

  defp first_line(text) do
    text
    |> String.split(~r/\r?\n/, parts: 2)
    |> List.first()
    |> String.trim()
  end

  defp sort_key(entry), do: String.downcase(entry.basename)
end
