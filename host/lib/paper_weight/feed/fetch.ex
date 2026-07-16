defmodule PaperWeight.Feed.Fetch do
  @moduledoc """
  Read-only boundary between a feed provider and snapshot construction.

  Provider modules implement `fetch_posts/1`; no mutation callbacks are part of
  this behaviour.
  """

  alias PaperWeight.Feed.{Config, Snapshot}

  @callback fetch_posts(Config.t()) :: {:ok, [map()]} | {:error, term()}

  @spec fetch_snapshot(Config.t()) :: {:ok, Snapshot.t()} | {:error, term()}
  def fetch_snapshot(%Config{} = config) do
    fetch_snapshot(config, DateTime.utc_now())
  end

  @spec fetch_snapshot(Config.t(), DateTime.t()) :: {:ok, Snapshot.t()} | {:error, term()}
  def fetch_snapshot(%Config{} = config, now) do
    case config.client.fetch_posts(config) do
      {:ok, posts} when is_list(posts) -> {:ok, Snapshot.build(posts, config, now)}
      {:ok, other} -> {:error, {:invalid_provider_response, other}}
      {:error, reason} -> {:error, reason}
    end
  end
end
