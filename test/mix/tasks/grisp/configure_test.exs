defmodule Mix.Tasks.Grisp.ConfigureTest do
  use ExUnit.Case, async: false

  setup do
    Mix.Task.reenable("grisp.configure")
    Mix.shell(Mix.Shell.Process)

    root =
      System.tmp_dir!()
      |> Path.join("mix_grisp_task_#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)

    on_exit(fn ->
      File.rm_rf!(root)
      Mix.shell(Mix.Shell.IO)
    end)

    {:ok, root: root}
  end

  test "non-interactive mode creates the selected scaffold files", %{root: root} do
    File.cd!(root, fn ->
      Mix.Tasks.Grisp.Configure.run([
        "--interactive",
        "false",
        "--name",
        "demo",
        "--network",
        "true",
        "--wifi",
        "true"
      ])
    end)

    assert_received {:mix_shell, :info, ["Created config/config.exs"]}
    assert_received {:mix_shell, :info, ["Created grisp/grisp2/common/deploy/files/grisp.ini.mustache"]}
    assert_received {:mix_shell, :info, ["Created grisp/grisp2/common/deploy/files/wpa_supplicant.conf"]}
    assert_received {:mix_shell, :info, ["Created grisp/grisp2/common/deploy/files/erl_inetrc"]}

    assert File.exists?(Path.join(root, "config/config.exs"))
    assert File.exists?(Path.join(root, "grisp/grisp2/common/deploy/files/grisp.ini.mustache"))
    assert File.exists?(Path.join(root, "grisp/grisp2/common/deploy/files/wpa_supplicant.conf"))
    assert File.exists?(Path.join(root, "grisp/grisp2/common/deploy/files/erl_inetrc"))
  end

  test "rerunning in non-interactive mode reports skipped files", %{root: root} do
    args = [
      "--interactive",
      "false",
      "--name",
      "demo",
      "--network",
      "true"
    ]

    File.cd!(root, fn ->
      Mix.Tasks.Grisp.Configure.run(args)
      Mix.Task.reenable("grisp.configure")
      Mix.Tasks.Grisp.Configure.run(args)
    end)

    assert_received {:mix_shell, :info, ["Skipped config/config.exs"]}
    assert_received {:mix_shell, :info, ["Skipped grisp/grisp2/common/deploy/files/grisp.ini.mustache"]}
    assert_received {:mix_shell, :info, ["Skipped grisp/grisp2/common/deploy/files/erl_inetrc"]}
  end

  test "interactive mode is explicitly rejected for now", %{root: root} do
    assert_raise Mix.Error, "Interactive mode is not implemented yet. Use --interactive false.", fn ->
      File.cd!(root, fn ->
        Mix.Tasks.Grisp.Configure.run(["--name", "demo"])
      end)
    end
  end

  test "invalid boolean values are rejected", %{root: root} do
    assert_raise Mix.Error, ~s(Invalid boolean value: "maybe"), fn ->
      File.cd!(root, fn ->
        Mix.Tasks.Grisp.Configure.run([
          "--interactive",
          "maybe",
          "--name",
          "demo"
        ])
      end)
    end
  end

  test "unknown options are rejected", %{root: root} do
    assert_raise Mix.Error, "Invalid options: --unknown", fn ->
      File.cd!(root, fn ->
        Mix.Tasks.Grisp.Configure.run([
          "--interactive",
          "false",
          "--name",
          "demo",
          "--unknown",
          "value"
        ])
      end)
    end
  end
end
