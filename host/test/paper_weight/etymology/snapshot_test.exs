defmodule PaperWeight.Etymology.SnapshotTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Etymology.{Corpus, Snapshot}

  defp snap(opts \\ [date: ~D[2026-07-15]]), do: Snapshot.assemble(Corpus.travel(), opts)

  test "assemble/2 produces the EtymologySnapshotV1 field set" do
    s = snap()

    for key <- Snapshot.required_keys() do
      assert Map.has_key?(s, key), "missing key #{key}"
    end

    assert s["as_of"] == "2026-07-15"
    assert s["date_label"] == "wed jul 15"
    assert s["stale"] == false
    assert s["source"] == "etymonline snapshot"
    assert s["depth"] == 3
  end

  test "word block carries display metadata" do
    word = snap()["word"]

    assert word["headword"] == "travel"
    assert word["language"] == "modern english"
    assert word["part_of_speech"] == "verb"
    assert word["gloss"] == "to make a journey"
    assert word["cousins"] == ["travail", "travolator"]
    assert is_binary(word["summary"])
  end

  test "trace is a nested map terminating in a root with null from" do
    trace = snap()["trace"]

    assert trace["form"] == "travel"
    assert trace["period"] == "now"
    assert trace["root"] == false

    root = trace["from"]["from"]["from"]
    assert root["form"] == "trepālium"
    assert root["root"] == true
    assert root["from"] == nil
    assert Enum.map(root["components"], & &1["form"]) == ["trēs", "pālus"]
  end

  test "splits_into branches survive assembly with note keys" do
    travailler = snap()["trace"]["from"]["from"]

    assert travailler["form"] == "travailler"
    assert travailler["splits_into"] == [
             %{"form" => "travel", "note" => "en"},
             %{"form" => "travail", "note" => "en/fr"}
           ]
  end

  test "mark_stale flips only the stale flag" do
    s = snap()
    stale = Snapshot.mark_stale(s)
    assert stale["stale"] == true
    assert stale["word"] == s["word"]
    assert stale["trace"] == s["trace"]
  end
end
