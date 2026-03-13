defmodule MixGrisp.Configure.RendererTest do
  use ExUnit.Case, async: true

  alias MixGrisp.Configure
  alias MixGrisp.Configure.Renderer
  alias MixGrisp.Configure.TemplatePlan

  setup do
    root =
      System.tmp_dir!()
      |> Path.join("mix_grisp_renderer_#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, root: root}
  end

  test "renderer creates files for the selected plan", %{root: root} do
    config =
      Configure.defaults()
      |> Map.merge(%{
        name: "demo",
        network: true,
        wifi: true
      })

    plan = TemplatePlan.build(config)
    result = Renderer.apply(plan, config, root: root)

    assert Enum.sort(result.created) == Enum.sort(Enum.map(plan, & &1.target))
    assert result.skipped == []

    assert String.trim(File.read!(Path.join(root, "config/config.exs"))) == "import Config"

    grisp_ini =
      root
      |> Path.join("grisp/grisp2/common/deploy/files/grisp.ini.mustache")
      |> File.read!()

    assert grisp_ini =~ "hostname=GRISP_HOSTNAME"
    assert grisp_ini =~ "wpa=wpa_supplicant.conf"

    wpa_supplicant =
      root
      |> Path.join("grisp/grisp2/common/deploy/files/wpa_supplicant.conf")
      |> File.read!()

    assert wpa_supplicant =~ ~s(ssid="WLAN_SSID")
    assert wpa_supplicant =~ ~s(psk="WLAN_PASSWORD")
  end

  test "renderer skips files that already exist", %{root: root} do
    config =
      Configure.defaults()
      |> Map.merge(%{
        name: "demo",
        network: true
      })

    plan = TemplatePlan.build(config)

    first_run = Renderer.apply(plan, config, root: root)
    second_run = Renderer.apply(plan, config, root: root)

    assert first_run.skipped == []
    assert Enum.sort(second_run.skipped) == Enum.sort(Enum.map(plan, & &1.target))
    assert second_run.created == []
  end

  test "renderer omits inetrc flag when grisp_io is enabled", %{root: root} do
    config =
      Configure.defaults()
      |> Map.merge(%{
        name: "demo",
        network: true,
        grisp_io: true
      })

    plan = TemplatePlan.build(config)
    Renderer.apply(plan, config, root: root)

    grisp_ini =
      root
      |> Path.join("grisp/grisp2/common/deploy/files/grisp.ini.mustache")
      |> File.read!()

    assert grisp_ini =~ "-extra --no-halt"
    refute File.exists?(Path.join(root, "grisp/grisp2/common/deploy/files/erl_inetrc"))
  end
end
