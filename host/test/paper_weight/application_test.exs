defmodule PaperWeight.ApplicationTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Application, as: App

  @all_disabled %{
    weather: :disabled,
    spotify: :disabled,
    photo: :disabled,
    photo_library_dir: nil,
    gateway: :disabled,
    gateway_port: 9138,
    gateway_stubs: :none
  }

  defp getenv(values), do: fn name -> Map.get(values, name) end

  @fake_weather_vars %{
    "WEATHER_LAT" => "0.0",
    "WEATHER_LON" => "0.0"
  }
  @fake_spotify_vars %{
    "SPOTIFY_CLIENT_ID" => "fake-client-id",
    "SPOTIFY_CLIENT_SECRET" => "fake-client-secret",
    "SPOTIFY_REFRESH_TOKEN" => "fake-refresh-token"
  }

  describe "children/1 (pure)" do
    test "zero-env: every service disabled yields only the shared Dither cache" do
      assert [{PaperWeight.Dither.Cache, _opts}] = App.children(@all_disabled)
    end

    test "all-enabled config yields three service child specs plus the Dither cache" do
      config = %{
        weather: :enabled,
        spotify: :enabled,
        photo: :enabled,
        photo_library_dir: "/tmp/photos",
        gateway: :disabled,
        gateway_port: 9138,
        gateway_stubs: :none
      }

      modules = config |> App.children() |> Enum.map(&elem(&1, 0))

      assert length(modules) == 4

      assert modules == [
               PaperWeight.Dither.Cache,
               PaperWeight.Weather.Service,
               PaperWeight.Spotify.Service,
               PaperWeight.Photo.Service
             ]
    end

    test "weather-only default (weather enabled, rest disabled) matches prior behavior" do
      config = %{@all_disabled | weather: :enabled}

      assert [{PaperWeight.Dither.Cache, _}, {PaperWeight.Weather.Service, opts}] =
               App.children(config)

      assert Keyword.get(opts, :name) == PaperWeight.Weather.Service
    end

    test "photo child carries the configured library_dir" do
      config = %{@all_disabled | photo: :enabled, photo_library_dir: "/srv/photos"}

      assert [{PaperWeight.Photo.Service, opts}] =
               config
               |> App.children()
               |> Enum.reject(&match?({PaperWeight.Dither.Cache, _}, &1))

      assert Keyword.get(opts, :library_dir) == "/srv/photos"
      assert Keyword.get(opts, :name) == PaperWeight.Photo.Service
    end

    test "each service can be enabled independently of the others" do
      for {key, module} <- [
            spotify: PaperWeight.Spotify.Service,
            photo: PaperWeight.Photo.Service
          ] do
        config = Map.put(@all_disabled, key, :enabled)
        modules = config |> App.children() |> Enum.map(&elem(&1, 0))

        assert modules == [PaperWeight.Dither.Cache, module]
      end
    end
  end

  describe "config_from_env/0 (impure edge)" do
    test "test-env config disables every service by default" do
      assert App.config_from_env() == %{
               weather: :disabled,
               spotify: :disabled,
               photo: :disabled,
               photo_library_dir: nil,
               gateway: :disabled,
               gateway_port: 9138,
               gateway_stubs: :none
             }
    end
  end

  describe "resolve_config/1 (pure, injectable — P7 live-runtime contract)" do
    test "no env: matches the compiled test-env default (all disabled)" do
      assert App.resolve_config(getenv(%{})).weather == :disabled
      assert App.resolve_config(getenv(%{})).spotify == :disabled
    end

    test "PAPER_WEIGHT_WEATHER_ENABLED=true with missing required vars raises naming them" do
      assert_raise ArgumentError,
                   "weather enabled but missing required env vars: WEATHER_LAT, WEATHER_LON",
                   fn ->
                     App.resolve_config(getenv(%{"PAPER_WEIGHT_WEATHER_ENABLED" => "true"}))
                   end
    end

    test "PAPER_WEIGHT_WEATHER_ENABLED=true with all required vars present enables, no raise" do
      values = Map.put(@fake_weather_vars, "PAPER_WEIGHT_WEATHER_ENABLED", "true")

      assert App.resolve_config(getenv(values)).weather == :enabled
    end

    test "enable var accepts 1/ENABLED case-insensitively, same as true" do
      for literal <- ["1", "ENABLED", "Enabled", "TRUE"] do
        values = Map.put(@fake_weather_vars, "PAPER_WEIGHT_WEATHER_ENABLED", literal)

        assert App.resolve_config(getenv(values)).weather == :enabled
      end
    end

    test "an unrecognized enable value falls back to the compiled default" do
      values = Map.put(@fake_weather_vars, "PAPER_WEIGHT_WEATHER_ENABLED", "maybe")

      assert App.resolve_config(getenv(values)).weather == :disabled
    end

    test "spotify enables independently with its own fake vars, no cross-talk" do
      values = Map.put(@fake_spotify_vars, "PAPER_WEIGHT_SPOTIFY_ENABLED", "true")

      config = App.resolve_config(getenv(values))

      assert config.spotify == :enabled
      assert config.weather == :disabled
    end

    test "PAPER_WEIGHT_GATEWAY_STUBS=all forces every lane off and skips validation entirely" do
      values = %{
        "PAPER_WEIGHT_GATEWAY_STUBS" => "all",
        "PAPER_WEIGHT_WEATHER_ENABLED" => "true",
        "PAPER_WEIGHT_SPOTIFY_ENABLED" => "true"
      }

      config = App.resolve_config(getenv(values))

      assert config.weather == :disabled
      assert config.spotify == :disabled
      assert config.gateway_stubs == :all
    end
  end

  describe "gateway stubs profile (W3-F)" do
    test "stubs: :all starts three stub services + Bandit, no real domain children" do
      config = %{
        @all_disabled
        | gateway: :enabled,
          gateway_stubs: :all,
          gateway_port: 9199
      }

      children = App.children(config)

      modules =
        Enum.map(children, fn
          {mod, _opts} ->
            mod

          %{id: {PaperWeight.Gateway.StubService, role}} ->
            {PaperWeight.Gateway.StubService, role}

          other ->
            other
        end)

      assert PaperWeight.Dither.Cache in modules
      assert Bandit in modules
      refute PaperWeight.Weather.Service in modules
      refute PaperWeight.Spotify.Service in modules
      refute PaperWeight.Photo.Service in modules

      assert {Bandit, opts} = Enum.find(children, &match?({Bandit, _}, &1))
      assert Keyword.get(opts, :port) == 9199
      assert {PaperWeight.Gateway.Endpoint, endpoint_opts} = Keyword.get(opts, :plug)

      assert Keyword.get(endpoint_opts, :adapters) == PaperWeight.Gateway.Stubs.adapters()
    end
  end

  describe "gateway_child (via children/1)" do
    test "disabled gateway yields no Bandit child" do
      refute Enum.any?(App.children(@all_disabled), &match?({Bandit, _}, &1))
    end

    test "enabled gateway yields a Bandit child bound to gateway_port" do
      config = %{@all_disabled | gateway: :enabled, gateway_port: 9999}

      assert [{Bandit, opts}] =
               config
               |> App.children()
               |> Enum.reject(&match?({PaperWeight.Dither.Cache, _}, &1))

      assert Keyword.get(opts, :port) == 9999
      assert {PaperWeight.Gateway.Endpoint, endpoint_opts} = Keyword.get(opts, :plug)

      assert Keyword.get(endpoint_opts, :adapters) == %{
               weather: nil,
               spotify: nil,
               photo: nil
             }
    end

    test "gateway adapters only reference services that are themselves enabled" do
      config = %{@all_disabled | gateway: :enabled, weather: :enabled}

      assert [{Bandit, opts}] =
               config
               |> App.children()
               |> Enum.reject(&match?({PaperWeight.Dither.Cache, _}, &1))
               |> Enum.reject(&match?({PaperWeight.Weather.Service, _}, &1))

      assert {PaperWeight.Gateway.Endpoint, endpoint_opts} = Keyword.get(opts, :plug)

      assert Keyword.get(endpoint_opts, :adapters) == %{
               weather: PaperWeight.Weather.Service,
               spotify: nil,
               photo: nil
             }
    end
  end

  describe "start/2 wiring" do
    test "photo child spec is startable with an injected temp library dir" do
      dir = System.tmp_dir!()

      {:ok, pid} =
        start_supervised(
          {PaperWeight.Photo.Service,
           [
             name: :photo_wire_test,
             library_dir: dir,
             auto_tick: false
           ]}
        )

      assert Process.alive?(pid)
    end
  end
end
