defmodule PaperWeight.Spotify.Config do
  @moduledoc """
  Spotify service configuration. Secrets come from env unless overridden in opts
  (tests always override — never commit tokens).
  """

  @type t :: %{
          client_id: String.t() | nil,
          client_secret: String.t() | nil,
          refresh_token: String.t() | nil,
          poll_ms: pos_integer(),
          api_base: String.t(),
          accounts_token_url: String.t()
        }

  @default_poll_ms 5_000
  @default_api_base "https://api.spotify.com/v1"
  @default_accounts_token_url "https://accounts.spotify.com/api/token"

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %{
      client_id: Keyword.get(opts, :client_id, System.get_env("SPOTIFY_CLIENT_ID")),
      client_secret: Keyword.get(opts, :client_secret, System.get_env("SPOTIFY_CLIENT_SECRET")),
      refresh_token: Keyword.get(opts, :refresh_token, System.get_env("SPOTIFY_REFRESH_TOKEN")),
      poll_ms: Keyword.get(opts, :poll_ms, @default_poll_ms),
      api_base: Keyword.get(opts, :api_base, @default_api_base),
      accounts_token_url: Keyword.get(opts, :accounts_token_url, @default_accounts_token_url)
    }
  end
end
