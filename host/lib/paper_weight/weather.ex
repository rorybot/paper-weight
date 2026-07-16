defmodule PaperWeight.Weather do
  @moduledoc """
  Public weather lane API (W1).

  Pure: `grade_uv/1`, `walk_verdict/1`.  
  Impure: `fetch_snapshot/1`, `fetch_snapshot/2`.  
  OTP: `PaperWeight.Weather.Service`.
  """

  alias PaperWeight.Weather.{Config, Fetch, Grade, Service, Verdict}

  @doc "Pure UV index → grade atom (`:extreme` | `:high` | `:low`)."
  @spec grade_uv(number()) :: Grade.grade()
  defdelegate grade_uv(index), to: Grade

  @doc "Pure walk-verdict sentence from temp / UV / precip inputs."
  @spec walk_verdict(Verdict.inputs()) :: String.t()
  defdelegate walk_verdict(inputs), to: Verdict

  @doc "Impure: build a full WeatherSnapshotV1 map (string keys)."
  @spec fetch_snapshot(keyword() | Config.t()) :: {:ok, map()} | {:error, term()}
  def fetch_snapshot(config_or_opts \\ [])

  def fetch_snapshot(opts) when is_list(opts) do
    fetch_snapshot(Config.new(opts), Fetch.default_http_get())
  end

  def fetch_snapshot(%{} = config) do
    fetch_snapshot(config, Fetch.default_http_get())
  end

  @spec fetch_snapshot(Config.t() | keyword(), Fetch.http_get()) ::
          {:ok, map()} | {:error, term()}
  def fetch_snapshot(opts, http_get) when is_list(opts) and is_function(http_get, 2) do
    Fetch.fetch_snapshot(Config.new(opts), http_get)
  end

  def fetch_snapshot(%{} = config, http_get) when is_function(http_get, 2) do
    Fetch.fetch_snapshot(config, http_get)
  end

  defdelegate start_link(opts \\ []), to: Service
  defdelegate get_snapshot(server), to: Service
  defdelegate refresh_now(server), to: Service
end
