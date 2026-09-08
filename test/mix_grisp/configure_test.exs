defmodule MixGrisp.ConfigureTest do
  use ExUnit.Case, async: false

  setup do
    previous_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)

    root =
      System.tmp_dir!()
      |> Path.join("mix_grisp_configure_#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)

    on_exit(fn ->
      File.rm_rf!(root)
      Mix.shell(previous_shell)
    end)

    {:ok, root: root}
  end

  test "does not prompt again for values supplied on the command line", %{root: root} do
    File.cd!(root, fn ->
      MixGrisp.Configure.run(
        interactive: true,
        name: "demo",
        otp_version: "29",
        jit: true,
        dest: "/tmp/grisp",
        wifi: false,
        grisp_io: false,
        epmd: false
      )
    end)

    refute_received {:mix_shell, :prompt, _message}
  end

  test "accepts true and false as explicit jit values", %{root: root} do
    File.cd!(root, fn ->
      Mix.Task.reenable("grisp.configure")

      Mix.Tasks.Grisp.Configure.run([
        "--no-interactive",
        "--name",
        "jit_enabled",
        "--jit",
        "true"
      ])

      Mix.Task.reenable("grisp.configure")

      Mix.Tasks.Grisp.Configure.run([
        "--no-interactive",
        "--name",
        "jit_disabled",
        "--jit",
        "false"
      ])
    end)

    assert File.read!(Path.join(root, "jit_enabled/mix.exs")) =~ "jit: true"
    assert File.read!(Path.join(root, "jit_disabled/mix.exs")) =~ "jit: false"
  end

  test "re-prompts until a valid application name is entered", %{root: root} do
    send(self(), {:mix_shell_input, :prompt, ""})
    send(self(), {:mix_shell_input, :prompt, "valid_name"})

    result =
      File.cd!(root, fn ->
        MixGrisp.Configure.run(
          interactive: true,
          name: "",
          otp_version: "29",
          jit: true,
          dest: "/tmp/grisp",
          wifi: false,
          grisp_io: false,
          epmd: false
        )
      end)

    assert result.name == "valid_name"
    assert_received {:mix_shell, :error, [_message]}
  end

  test "re-prompts for invalid yes or no answers", %{root: root} do
    send(self(), {:mix_shell_input, :prompt, "maybe"})
    send(self(), {:mix_shell_input, :prompt, "n"})

    File.cd!(root, fn ->
      MixGrisp.Configure.run(
        interactive: true,
        name: "demo",
        otp_version: "29",
        jit: true,
        dest: "/tmp/grisp",
        grisp_io: false,
        epmd: false
      )
    end)

    assert_received {:mix_shell, :error, ["Expected yes or no"]}
  end

  test "preserves files when the user accepts an existing project directory", %{root: root} do
    project = Path.join(root, "demo")
    File.mkdir_p!(project)
    File.write!(Path.join(project, "mix.exs"), "# existing project\n")
    send(self(), {:mix_shell_input, :prompt, "y"})

    File.cd!(root, fn ->
      MixGrisp.Configure.run(
        interactive: true,
        name: "demo",
        otp_version: "29",
        jit: true,
        dest: "/tmp/grisp",
        wifi: false,
        grisp_io: false,
        epmd: false
      )
    end)

    assert File.read!(Path.join(project, "mix.exs")) == "# existing project\n"
    assert File.exists?(Path.join(project, "config/config.exs"))
  end

  test "generates an Ethernet configuration without enabling WLAN", %{root: root} do
    result =
      File.cd!(root, fn ->
        MixGrisp.Configure.run(
          interactive: false,
          name: "demo"
        )
      end)

    grisp_ini =
      File.read!(Path.join(result.root, "grisp/grisp2/common/deploy/files/grisp.ini.mustache"))

    refute grisp_ini =~ "wlan=enable"
    assert grisp_ini =~ ~s(-kernel inetrc "./erl_inetrc")
    assert grisp_ini =~ "-user elixir -extra +iex --no-halt"
    assert grisp_ini =~ "on_exit = reboot"
    assert grisp_ini =~ "on_crash = reboot"
  end

  test "enables Wi-Fi when either credential is supplied", %{root: root} do
    for {name, option} <- [{"ssid_only", {:ssid, "test-network"}}, {"psk_only", {:psk, "secret"}}] do
      result =
        File.cd!(root, fn ->
          MixGrisp.Configure.run([{:interactive, false}, {:name, name}, option])
        end)

      files = Path.join(result.root, "grisp/grisp2/common/deploy/files")
      grisp_ini = File.read!(Path.join(files, "grisp.ini.mustache"))

      assert grisp_ini =~ "wlan=enable"
      assert grisp_ini =~ "wpa=wpa_supplicant.conf"
      assert File.exists?(Path.join(files, "wpa_supplicant.conf"))
    end
  end

  test "generates a bootable GRiSP.io release configuration", %{root: root} do
    File.cd!(root, fn ->
      Mix.Task.reenable("grisp.configure")

      Mix.Tasks.Grisp.Configure.run([
        "--no-interactive",
        "--name",
        "connected",
        "--ssid",
        "test-network",
        "--psk",
        "secret",
        "--grisp-io-linking",
        "link-token"
      ])
    end)

    project = Path.join(root, "connected")
    mix_exs = File.read!(Path.join(project, "mix.exs"))
    config_exs = File.read!(Path.join(project, "config/config.exs"))
    files = Path.join(project, "grisp/grisp2/common/deploy/files")
    grisp_ini = File.read!(Path.join(files, "grisp.ini.mustache"))

    for dependency <- ~w(certifi grisp_cryptoauth grisp_updater_grisp2 grisp_connect) do
      assert mix_exs =~ ":#{dependency}"
    end

    assert mix_exs =~ ~s({:grisp_cryptoauth, "~> 2.6"})
    assert mix_exs =~ ~s({:grisp_connect, "~> 3.0.0"})
    assert mix_exs =~ ~s({:grisp_updater_grisp2, "~> 1.0", runtime: false})
    assert mix_exs =~ ~s({:grisp, "~> 2.12", override: true})
    assert mix_exs =~ "applications: [sasl: :permanent, grisp_updater_grisp2: :load]"

    assert config_exs =~ "config :grisp_keychain"
    assert config_exs =~ "config :grisp_cryptoauth"
    assert config_exs =~ "config :grisp_connect"
    assert config_exs =~ ~s(device_linking_token: "link-token")
    assert config_exs =~ "config :grisp_updater"
    refute config_exs =~ "config :kernel"
    refute config_exs =~ "logger: []"
    assert {:ok, _quoted} = Code.string_to_quoted(config_exs)

    assert grisp_ini =~ "wlan=enable"
    assert grisp_ini =~ "wpa=wpa_supplicant.conf"
    assert grisp_ini =~ "-kernel logger_level notice"
    refute grisp_ini =~ "__EPMD_ARGS__"
    refute grisp_ini =~ "__GRISP_IO_ARGS__"
    refute grisp_ini =~ "__WIFI_CONFIG__"
    refute config_exs =~ "__GRISP_CONNECT_CONFIG__"
    assert File.exists?(Path.join(files, "wpa_supplicant.conf"))
    assert File.exists?(Path.join(files, "erl_inetrc"))
  end
end
