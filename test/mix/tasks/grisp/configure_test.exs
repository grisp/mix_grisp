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
        "--network-type",
        "wifi"
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

  test "interactive mode prompts for missing values and creates files", %{root: root} do
    send(self(), {:mix_shell_input, :prompt, "demo"})
    send(self(), {:mix_shell_input, :prompt, "y"})
    send(self(), {:mix_shell_input, :prompt, "wifi"})
    send(self(), {:mix_shell_input, :prompt, "mywifi"})
    send(self(), {:mix_shell_input, :prompt, "secret"})
    send(self(), {:mix_shell_input, :prompt, "n"})
    send(self(), {:mix_shell_input, :prompt, "n"})

    File.cd!(root, fn ->
      Mix.Tasks.Grisp.Configure.run([])
    end)

    assert_received {:mix_shell, :prompt, ["OTP application name: "]}
    assert_received {:mix_shell, :prompt, ["Enable network configuration? [y/N]: "]}
    assert_received {:mix_shell, :prompt, ["Network type? [ethernet/wifi]: "]}
    assert_received {:mix_shell, :prompt, ["Wi-Fi SSID (leave blank to skip): "]}
    assert_received {:mix_shell, :prompt, ["Wi-Fi PSK (leave blank to skip): "]}
    assert_received {:mix_shell, :prompt, ["Enable GRiSP.io integration? [y/N]: "]}
    assert_received {:mix_shell, :prompt, ["Enable epmd configuration? [y/N]: "]}

    assert File.exists?(Path.join(root, "config/config.exs"))
    assert File.exists?(Path.join(root, "grisp/grisp2/common/deploy/files/grisp.ini.mustache"))
    assert File.exists?(Path.join(root, "grisp/grisp2/common/deploy/files/wpa_supplicant.conf"))
    assert File.exists?(Path.join(root, "grisp/grisp2/common/deploy/files/erl_inetrc"))
  end

  test "interactive mode skips prompts for values already provided", %{root: root} do
    send(self(), {:mix_shell_input, :prompt, "ethernet"})
    send(self(), {:mix_shell_input, :prompt, "n"})
    send(self(), {:mix_shell_input, :prompt, "n"})

    File.cd!(root, fn ->
      Mix.Tasks.Grisp.Configure.run([
        "--name",
        "demo",
        "--network",
        "true"
      ])
    end)

    refute_received {:mix_shell, :prompt, ["OTP application name: "]}
    refute_received {:mix_shell, :prompt, ["Enable network configuration? [y/N]: "]}
    assert_received {:mix_shell, :prompt, ["Network type? [ethernet/wifi]: "]}
    assert_received {:mix_shell, :prompt, ["Enable GRiSP.io integration? [y/N]: "]}
    assert_received {:mix_shell, :prompt, ["Enable epmd configuration? [y/N]: "]}
  end

  test "interactive mode skips wifi detail prompts when wifi is disabled", %{root: root} do
    send(self(), {:mix_shell_input, :prompt, "demo"})
    send(self(), {:mix_shell_input, :prompt, "y"})
    send(self(), {:mix_shell_input, :prompt, "ethernet"})
    send(self(), {:mix_shell_input, :prompt, "n"})
    send(self(), {:mix_shell_input, :prompt, "n"})

    File.cd!(root, fn ->
      Mix.Tasks.Grisp.Configure.run([])
    end)

    refute_received {:mix_shell, :prompt, ["Wi-Fi SSID (leave blank to skip): "]}
    refute_received {:mix_shell, :prompt, ["Wi-Fi PSK (leave blank to skip): "]}
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
