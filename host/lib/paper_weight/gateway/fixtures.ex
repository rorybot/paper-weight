defmodule PaperWeight.Gateway.Fixtures do
  @moduledoc """
  Deterministic channel payloads for the W3-F `gateway: [stubs: :all]` profile.

  Shapes mirror the device-UI screen fixtures under `src/device-ui/src/screens/*/fixture.ts`
  so desktop smoke can render every managed channel without external APIs or secrets.
  """

  @tiny_pbm "UDQKMTYgMTYKqlVVqqpVVaqqVVWqqlVVqqpVVaqqVVWqqlVVqqpVVao="

  @spec now_playing() :: map()
  def now_playing do
    %{
      "as_of" => "2026-07-16T14:32:00Z",
      "stale" => false,
      "track" => %{
        "title" => "Galactic",
        "artist" => "Tenure",
        "album" => "Sink · 2020",
        "art_pbm_base64" => @tiny_pbm,
        "duration_ms" => 221_000,
        "progress_ms" => 82_000
      },
      "queue" => [
        %{"title" => "Last'en", "artist" => "Tenure"},
        %{"title" => "Housebound", "artist" => "Tenure"},
        %{"title" => "Natural Light", "artist" => "Sink"},
        %{"title" => "Circuits", "artist" => "Tenure"},
        %{"title" => "Soft Static", "artist" => "Night Bus"}
      ],
      "volume" => %{"level" => 70},
      "lyrics" => %{
        "lines" => [
          %{"t_ms" => 0, "text" => "tape hiss, then a door"},
          %{"t_ms" => 12_000, "text" => "we left the porch light on"},
          %{"t_ms" => 28_000, "text" => "for something that never parks"},
          %{"t_ms" => 44_000, "text" => "galactic — not far, just high"},
          %{"t_ms" => 62_000, "text" => "count the windows in the dark"}
        ]
      }
    }
  end

  @spec playlist() :: map()
  def playlist do
    %{
      as_of: "2026-07-16T20:00:00Z",
      stale: false,
      playlists: [
        %{id: "pl-sink", name: "Sink", cover_pbm_base64: nil},
        %{id: "pl-drive", name: "drive.exe", cover_pbm_base64: nil},
        %{id: "pl-heavy", name: "heavy rotation", cover_pbm_base64: nil},
        %{id: "pl-kentucky", name: "kentucky basement", cover_pbm_base64: nil},
        %{id: "pl-storm", name: "storm watching", cover_pbm_base64: nil},
        %{id: "pl-radar", name: "release radar", cover_pbm_base64: nil},
        %{id: "pl-late", name: "late night mix", cover_pbm_base64: nil},
        %{id: "pl-commute", name: "commute loop", cover_pbm_base64: nil}
      ]
    }
  end

  @spec weather() :: map()
  def weather do
    day = fn date, high, low, summary ->
      %{"date" => date, "high_f" => high, "low_f" => low, "summary" => summary}
    end

    %{
      "location_label" => "exampleville, ex",
      "as_of" => "2026-07-16T20:00:00Z",
      "stale" => false,
      "current" => %{"temp_f" => 92, "summary" => "sunny"},
      "walk_verdict" => "good window right now — but be home by 5. storms & strong sun midday.",
      "uv" => %{"index" => 9.2, "grade" => "extreme"},
      "days5" => [
        day.("2026-07-15", 92, 61, "pm storms"),
        day.("2026-07-16", 96, 63, "sunny"),
        day.("2026-07-17", 89, 60, "pm storms"),
        day.("2026-07-18", 97, 64, "hot, clear"),
        day.("2026-07-19", 85, 58, "storms")
      ],
      "days7" => [
        day.("2026-07-15", 92, 61, "pm storms"),
        day.("2026-07-16", 96, 63, "sunny"),
        day.("2026-07-17", 89, 60, "pm storms"),
        day.("2026-07-18", 97, 64, "hot, clear"),
        day.("2026-07-19", 85, 58, "storms"),
        day.("2026-07-20", 88, 59, "mostly sunny"),
        day.("2026-07-21", 91, 62, "sunny")
      ],
      "hourly_uv" => [
        %{"hour_local" => "13:00", "index" => 9.5},
        %{"hour_local" => "14:00", "index" => 10.1},
        %{"hour_local" => "15:00", "index" => 7.2},
        %{"hour_local" => "16:00", "index" => 6.8},
        %{"hour_local" => "17:00", "index" => 6.1},
        %{"hour_local" => "18:00", "index" => 4.0},
        %{"hour_local" => "19:00", "index" => 2.5},
        %{"hour_local" => "20:00", "index" => 1.2},
        %{"hour_local" => "21:00", "index" => 0.4},
        %{"hour_local" => "22:00", "index" => 6.5}
      ]
    }
  end

  @spec feed() :: map()
  def feed do
    %{
      as_of: "2026-07-15T14:20:00Z",
      stale: false,
      posts: [
        %{
          id: "p-nws",
          handle: "@NWSBoulder",
          body: "Severe t-storm watch for the metro until 9 PM. Hail possible south of town.",
          time_label: "12m",
          accent: "#ff6b35"
        },
        %{
          id: "p-tenure",
          handle: "@tenureband",
          body: "\"new song out of the basement friday. it's about a dog. sort of.\"",
          time_label: "41m",
          accent: "#a0533e"
        },
        %{
          id: "p-cth",
          handle: "@carthinghacks",
          body: "the wheel encoder is just evdev. everything is possible.",
          time_label: "1h",
          accent: "#f7c948"
        },
        %{
          id: "p-archive",
          handle: "@internetarchive",
          body: "Preserving useful knowledge, one snapshot at a time.",
          time_label: "2h",
          accent: "#4ecdc4"
        },
        %{
          id: "p-nasa",
          handle: "@nasa",
          body: "A new view of the night sky and the worlds beyond it.",
          time_label: "3h",
          accent: "#5b8def"
        }
      ]
    }
  end

  @spec photo() :: map()
  def photo do
    %{
      "as_of" => "2026-07-16T15:00:00Z",
      "stale" => false,
      "source" => "local library",
      "empty" => false,
      "index" => 1,
      "total" => 3,
      "caption" => "porch light, tuesday",
      "id" => "porch-light",
      "path" => "/library/porch-light.jpg",
      "kept" => false,
      "reprints_in_min" => 4,
      "reprint_interval_min" => 5,
      "art_pbm_base64" => @tiny_pbm
    }
  end
end
