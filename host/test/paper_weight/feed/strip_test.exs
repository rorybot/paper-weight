defmodule PaperWeight.Feed.StripTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Feed.Strip

  test "strips markup and normalizes handle and display age" do
    now = ~U[2026-07-16 13:00:00Z]

    raw = %{
      "id" => 42,
      "handle" => "RoryBot",
      "body" => "<p>Hello&nbsp; <b>world</b> &amp; friends\u200B</p>",
      "created_at" => "2026-07-16T12:57:00Z"
    }

    assert Strip.strip_post(raw, now) == %{
             id: "42",
             handle: "@rorybot",
             body: "Hello world & friends",
             time_label: "3m"
           }
  end
end
