defmodule PaperWeight.ApplicationTest do
  use ExUnit.Case, async: true

  alias PaperWeight.Application, as: App

  @all_disabled %{
    weather: :disabled,
    spotify: :disabled,
    feed: :disabled,
    photo: :disabled,
    photo_library_dir: nil,
    gateway: :disabled,
    gateway_port: 9138,
    gateway_stubs: :none
  }

  describe "children/1 (pure)" do
    test "zero-env: every service disabled yields only the shared Dither cache" do
      assert [{PaperWeight.Dither.Cache, _opts}] = App.children(@all_disabled)
    end

    test "all-enabled config yields four service child specs plus the Dither cache" do
      config = %{
        weather: :enabled,
        spotify: :enabled,
        feed: :enabled,
        photo: :enabled,
        photo_library_dir: "/tmp/photos",
        gateway: :disabled,
        gateway_port: 9138,
        gateway_stubs: :none
      }

      modules = config |> App.children() |> Enum.map(&elem(&1, 0))

      assert length(modules) == 5

      assert modules == [
               PaperWeight.Dither.Cache,
               PaperWeight.Weather.Service,
               PaperWeight.Spotify.Service,
               PaperWeight.Feed.Service,
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
            feed: PaperWeight.Feed.Service,
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
               feed: :disabled,
               photo: :disabled,
               photo_library_dir: nil,
               gateway: :disabled,
               gateway_port: 9138,
               gateway_stubs: :none
             }
    end
  end

  describe "gateway stubs profile (W3-F)" do
    test "stubs: :all starts four stub services + Bandit, no real domain children" do
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
      refute PaperWeight.Feed.Service in modules
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
               feed: nil,
               photo: nil
             }
    end

    test "gateway adapters only reference services that are themselves enabled" do
      config = %{@all_disabled | gateway: :enabled, weather: :enabled, feed: :enabled}

      assert [{Bandit, opts}] =
               config
               |> App.children()
               |> Enum.reject(&match?({PaperWeight.Dither.Cache, _}, &1))
               |> Enum.reject(&match?({PaperWeight.Weather.Service, _}, &1))
               |> Enum.reject(&match?({PaperWeight.Feed.Service, _}, &1))

      assert {PaperWeight.Gateway.Endpoint, endpoint_opts} = Keyword.get(opts, :plug)

      assert Keyword.get(endpoint_opts, :adapters) == %{
               weather: PaperWeight.Weather.Service,
               spotify: nil,
               feed: PaperWeight.Feed.Service,
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
