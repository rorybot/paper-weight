defmodule PaperWeight.Feed.Fetch.Fixture do
  @moduledoc """
  Deterministic read-only provider used for acceptance tests and local demos.
  """

  @behaviour PaperWeight.Feed.Fetch

  @posts [
    %{
      id: "fixture-101",
      handle: "@nasa",
      body: "A new view of the night sky &amp; the worlds beyond it.",
      time_label: "3m"
    },
    %{
      id: "fixture-102",
      handle: "@internetarchive",
      body: "Preserving useful knowledge, one snapshot at a time.",
      time_label: "18m"
    },
    %{
      id: "fixture-103",
      handle: "@publicdomainrev",
      body: "Today in the archive: strange machines and careful diagrams.",
      time_label: "1h"
    }
  ]

  @impl true
  def fetch_posts(_config), do: {:ok, @posts}
end
