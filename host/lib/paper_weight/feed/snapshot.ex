defmodule PaperWeight.Feed.Snapshot do
  @moduledoc """
  Builds immutable full-replacement feed snapshots from raw provider posts.
  """

  alias PaperWeight.Feed.{Accent, Config, Strip}

  @type post :: %{
          id: String.t(),
          handle: String.t(),
          body: String.t(),
          time_label: String.t(),
          accent: String.t()
        }

  @type t :: %{
          as_of: String.t(),
          stale: boolean(),
          posts: [post()]
        }

  @spec build([map()], Config.t()) :: t()
  def build(raw_posts, %Config{} = config), do: build(raw_posts, config, DateTime.utc_now())

  @spec build([map()], Config.t(), DateTime.t()) :: t()
  def build(raw_posts, %Config{} = config, now) do
    posts =
      raw_posts
      |> Enum.map(&Strip.strip_post(&1, now))
      |> filter_handles(config.handles)
      |> Enum.reject(&invalid_post?/1)
      |> Enum.take(config.limit)

    accents = posts |> Enum.map(& &1.handle) |> Accent.assign_accents()

    %{
      as_of: DateTime.to_iso8601(now),
      stale: false,
      posts: Enum.map(posts, &Map.put(&1, :accent, Map.fetch!(accents, &1.handle)))
    }
  end

  @spec empty_stale(DateTime.t()) :: t()
  def empty_stale(now \\ DateTime.utc_now()) do
    %{as_of: DateTime.to_iso8601(now), stale: true, posts: []}
  end

  @spec mark_stale(t()) :: t()
  def mark_stale(snapshot), do: %{snapshot | stale: true}

  defp filter_handles(posts, []), do: posts

  defp filter_handles(posts, handles) do
    allowed = MapSet.new(handles)
    Enum.filter(posts, &MapSet.member?(allowed, &1.handle))
  end

  defp invalid_post?(post) do
    post.id == "" or post.handle == "@" or post.body == ""
  end
end
