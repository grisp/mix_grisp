defmodule MixGrisp.Configure.ConfigPatcherTest do
  use ExUnit.Case, async: true

  alias MixGrisp.Configure
  alias MixGrisp.Configure.ConfigPatcher

  setup do
    root =
      System.tmp_dir!()
      |> Path.join("mix_grisp_config_#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(root, "config"))
    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, root: root}
  end

  test "patches config/config.exs for grisp_io", %{root: root} do
    config_path = Path.join(root, "config/config.exs")
    File.write!(config_path, "import Config\n")

    config =
      Configure.defaults()
      |> Map.merge(%{
        name: "demo",
        interactive: false,
        grisp_io: true,
        grisp_io_linking: true,
        token: "token"
      })

    result = ConfigPatcher.apply(config, root: root)
    patched = File.read!(config_path)

    assert result.status == :updated
    assert patched =~ "config :grisp_keychain"
    assert patched =~ "config :grisp_connect"
    assert patched =~ ~s(device_linking_token: "token")
    assert patched =~ "config :grisp_updater"
  end

  test "returns unchanged when grisp_io is disabled", %{root: root} do
    config_path = Path.join(root, "config/config.exs")
    File.write!(config_path, "import Config\n")

    config = Configure.defaults() |> Map.merge(%{name: "demo", interactive: false})

    result = ConfigPatcher.apply(config, root: root)

    assert result.status == :unchanged
    assert File.read!(config_path) == "import Config\n"
  end
end
