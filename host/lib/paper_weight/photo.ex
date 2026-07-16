defmodule PaperWeight.Photo do
  @moduledoc """
  Public photo lane API (H1).

  Pure: `Rotate.*`, `Snapshot.assemble/1`.  
  Impure: `Library.scan/1`, `Service` OTP.
  """

  alias PaperWeight.Photo.{Config, Library, Rotate, Service, Snapshot}

  @doc "Scan a library directory into ordered entries."
  @spec scan(Path.t() | Config.t()) :: [Library.entry()]
  def scan(%{} = config), do: Library.scan(config)
  def scan(dir) when is_binary(dir), do: Library.scan(Config.new(library_dir: dir))

  @doc "Pure: advance one photo and reset the reprint timer."
  defdelegate skip(state, now_ms), to: Rotate

  @doc "Pure: toggle keep-on-show pin for the current photo."
  defdelegate keep(state), to: Rotate

  @doc "Pure: auto-advance when the reprint deadline has passed (unless kept)."
  defdelegate tick(state, now_ms), to: Rotate

  @doc "Pure: assemble PhotoSnapshotV1 (string keys)."
  defdelegate assemble(parts), to: Snapshot

  defdelegate start_link(opts \\ []), to: Service
  defdelegate get_snapshot(server), to: Service
  defdelegate skip_photo(server), to: Service, as: :skip
  defdelegate keep_photo(server), to: Service, as: :keep
  defdelegate rescan(server), to: Service
end
