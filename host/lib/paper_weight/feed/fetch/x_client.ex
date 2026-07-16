defmodule PaperWeight.Feed.Fetch.XClient do
  @moduledoc """
  Placeholder boundary for a future authenticated, read-only X client.

  Wave F1 deliberately avoids a live dependency because X access may require a
  paid API tier. Supplying credentials does not initiate network traffic yet.
  """

  @behaviour PaperWeight.Feed.Fetch

  alias PaperWeight.Feed.Config

  @impl true
  def fetch_posts(%Config{api_token: nil}), do: {:error, :missing_api_credentials}

  def fetch_posts(%Config{}) do
    {:error, {:not_implemented, :x_read_only_client}}
  end
end
