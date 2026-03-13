defmodule MixGrisp.Configure.MixExsPatcherTest do
  use ExUnit.Case, async: true

  alias MixGrisp.Configure
  alias MixGrisp.Configure.MixExsPatcher

  setup do
    root =
      System.tmp_dir!()
      |> Path.join("mix_grisp_mix_exs_#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, root: root}
  end

  test "patches a simple mix new style mix.exs", %{root: root} do
    mix_exs = Path.join(root, "mix.exs")

    File.write!(mix_exs, """
    defmodule Demo.MixProject do
      use Mix.Project

      def project do
        [
          app: :demo,
          version: "0.1.0",
          deps: deps()
        ]
      end

      def application do
        [
          extra_applications: [:logger]
        ]
      end

      defp deps do
        []
      end
    end
    """)

    config =
      Configure.defaults()
      |> Map.merge(%{name: "demo", interactive: false, network: true, epmd: true, cookie: "grisp"})

    result = MixExsPatcher.apply(config, root: root)
    patched = File.read!(mix_exs)

    assert result.status == :updated
    assert patched =~ "grisp: grisp()"
    assert patched =~ "releases: releases()"
    assert patched =~ ~s({:grisp, "~> 2.4"})
    assert patched =~ ~s({:epmd, git: "https://github.com/erlang/epmd", ref: "4d1a59", runtime: false})
    assert patched =~ "included_applications: [:epmd]"
    assert patched =~ "def grisp do"
    assert patched =~ "def releases do"
  end

  test "returns manual steps for unsupported mix.exs shapes", %{root: root} do
    mix_exs = Path.join(root, "mix.exs")

    File.write!(mix_exs, """
    defmodule Demo.MixProject do
      use Mix.Project

      def project, do: custom_project()
      defp deps, do: custom_deps()
    end
    """)

    config = Configure.defaults() |> Map.merge(%{name: "demo", interactive: false})

    result = MixExsPatcher.apply(config, root: root)

    assert result.status == :manual
    assert Enum.any?(result.manual, &String.contains?(&1, "grisp: grisp()"))
  end
end
