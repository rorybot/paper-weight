defmodule PaperWeight.RuntimeContract do
  @moduledoc """
  Pure presence/non-empty check for the env vars a live lane needs, per
  `docs/architecture/live-runtime-contract-v1.md`. Deliberately does not
  parse or format-validate values — that stays with each lane's own
  `Config` module (`PaperWeight.Weather.Config`, `PaperWeight.Spotify.Config`),
  which this list must be kept in sync with by hand since P7 is not permitted
  to touch lane client internals.
  """

  @required_vars %{
    weather: ~w(WEATHER_LAT WEATHER_LON),
    spotify: ~w(SPOTIFY_CLIENT_ID SPOTIFY_CLIENT_SECRET SPOTIFY_REFRESH_TOKEN)
  }

  @type lane :: :weather | :spotify
  @type getenv :: (String.t() -> String.t() | nil)

  @doc """
  Returns the required var *names* (never values) that are missing or empty
  for `lane`, using `getenv` to look each one up.
  """
  @spec missing_vars(lane(), getenv()) :: [String.t()]
  def missing_vars(lane, getenv) when is_function(getenv, 1) do
    @required_vars
    |> Map.fetch!(lane)
    |> Enum.filter(fn name -> blank?(getenv.(name)) end)
  end

  defp blank?(nil), do: true
  defp blank?(""), do: true
  defp blank?(_), do: false
end
