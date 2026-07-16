defmodule PaperWeight.Feed.ServiceTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Feed.{Config, Service, Snapshot}

  test "a successful refresh atomically replaces posts and advances generation" do
    {:ok, responses} =
      Agent.start_link(fn ->
        [
          {:ok, snapshot([post("old", "@ada", "Old post")])},
          {:ok, snapshot([post("new", "@ada", "New post")])}
        ]
      end)

    service = start_service(responses)
    first = Service.current(service)
    second = Service.refresh(service)

    assert first.gen == 1
    assert Enum.map(first.snapshot.posts, & &1.id) == ["old"]
    assert second.gen == 2
    assert Enum.map(second.snapshot.posts, & &1.id) == ["new"]
    refute Enum.any?(second.snapshot.posts, &(&1.id == "old"))

    assert hd(first.snapshot.posts).accent == hd(second.snapshot.posts).accent
  end

  test "a failed refresh keeps the last full list and marks it stale" do
    {:ok, responses} =
      Agent.start_link(fn ->
        [
          {:ok, snapshot([post("kept", "@grus", "Keep me")])},
          {:error, :offline}
        ]
      end)

    service = start_service(responses)
    before_failure = Service.current(service)
    after_failure = Service.refresh(service)

    refute before_failure.snapshot.stale
    assert after_failure.snapshot.stale
    assert after_failure.snapshot.posts == before_failure.snapshot.posts
    assert after_failure.gen > before_failure.gen
    assert after_failure.last_error == :offline
  end

  defp start_service(responses) do
    fetcher = fn _config ->
      Agent.get_and_update(responses, fn [next | rest] -> {next, rest} end)
    end

    start_supervised!(
      {Service, name: nil, config: Config.new(refresh_ms: 60_000), fetcher: fetcher}
    )
  end

  defp snapshot(posts) do
    %{
      Snapshot.empty_stale(~U[2026-07-16 13:00:00Z])
      | stale: false,
        posts: posts
    }
  end

  defp post(id, handle, body) do
    %{
      id: id,
      handle: handle,
      body: body,
      time_label: "1m",
      accent: PaperWeight.Feed.Accent.accent_for(handle)
    }
  end
end
