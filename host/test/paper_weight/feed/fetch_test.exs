defmodule PaperWeight.Feed.FetchTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Feed.{Config, Fetch}
  alias PaperWeight.Feed.Fetch.Fixture

  defmodule FailureClient do
    @behaviour Fetch

    @impl true
    def fetch_posts(_config), do: {:error, :offline}
  end

  test "fixture provider yields at least three plain read-only posts" do
    config = Config.new(client: Fixture)

    assert {:ok, snapshot} = Fetch.fetch_snapshot(config, ~U[2026-07-16 13:00:00Z])
    assert length(snapshot.posts) >= 3

    assert Enum.all?(
             snapshot.posts,
             &(Map.keys(&1) |> Enum.sort() == [:accent, :body, :handle, :id, :time_label])
           )
  end

  test "provider failures remain explicit" do
    config = Config.new(client: FailureClient)
    assert {:error, :offline} = Fetch.fetch_snapshot(config)
  end
end
