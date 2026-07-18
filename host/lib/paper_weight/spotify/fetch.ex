defmodule PaperWeight.Spotify.Fetch do
  @moduledoc """
  Impure orchestration edge: ensures a valid access token, pulls now-playing +
  queue + volume and the user playlist list from the Spotify Web API, and
  assembles snapshots.

  HTTP is injected (see `PaperWeight.Spotify.Auth` / `PaperWeight.Spotify.Client`)
  so tests never hit the network or need real tokens.
  """

  alias PaperWeight.Spotify.{Auth, Client, Config, PlaylistSnapshot, Snapshot}

  @token_refresh_buffer_s 30

  @spec fetch_snapshot(Config.t(), Auth.token() | nil, Auth.http_post(), Client.http()) ::
          {:ok, Snapshot.t(), Auth.token()} | {:error, term()}
  def fetch_snapshot(config, token_state, http_post, http) do
    with {:ok, token} <- refresh_if_needed(config, token_state, http_post),
         {:ok, track} <- Client.now_playing(config, token.access_token, http),
         {:ok, queue} <- Client.queue(config, token.access_token, http),
         {:ok, volume_level} <- Client.volume(config, token.access_token, http) do
      snapshot =
        Snapshot.assemble(%{
          track: track,
          queue: queue,
          volume_level: volume_level,
          stale: false,
          art_pbm_base64: nil
        })

      {:ok, snapshot, token}
    end
  end

  @spec fetch_playlists(Config.t(), Auth.token() | nil, Auth.http_post(), Client.http()) ::
          {:ok, PlaylistSnapshot.t(), Auth.token()} | {:error, term()}
  def fetch_playlists(config, token_state, http_post, http) do
    with {:ok, token} <- refresh_if_needed(config, token_state, http_post),
         {:ok, playlists} <- Client.playlists(config, token.access_token, http) do
      snapshot =
        PlaylistSnapshot.assemble(%{
          playlists: playlists,
          stale: false
        })

      {:ok, snapshot, token}
    end
  end

  @doc "Reuse a still-valid cached token, otherwise refresh via the Accounts API."
  @spec refresh_if_needed(Config.t(), Auth.token() | nil, Auth.http_post()) ::
          {:ok, Auth.token()} | {:error, term()}
  def refresh_if_needed(config, token_state, http_post) do
    if token_fresh?(token_state) do
      {:ok, token_state}
    else
      Auth.refresh_access_token(config, http_post)
    end
  end

  defp token_fresh?(%{access_token: access_token, expires_at: %DateTime{} = expires_at})
       when is_binary(access_token) do
    DateTime.compare(
      expires_at,
      DateTime.add(DateTime.utc_now(), @token_refresh_buffer_s, :second)
    ) == :gt
  end

  defp token_fresh?(_), do: false
end
