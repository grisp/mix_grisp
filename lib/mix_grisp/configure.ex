defmodule MixGrisp.Configure do
  @moduledoc false

  @defaults [
    interactive: true,
    name: "robot",
    otp_version: "29",
    jit: true,
    dest: "/path/to/SD-card",
    desc: "A GRiSP application",
    copyright_year: nil,
    author_name: "Anonymous",
    author_email: "anonymous@example.org",
    network: false,
    wifi: false,
    grisp_io: false,
    grisp_io_linking: false,
    epmd: false,
    cookie: "grisp"
  ]

  def run(options) do
    config =
      options
      |> Keyword.merge(@defaults, fn _key, supplied, _default -> supplied end)
      |> Keyword.update!(:copyright_year, &(&1 || Integer.to_string(Date.utc_today().year)))
      |> prompt()

    validate!(config)
    root = Path.expand(config[:name])

    if File.exists?(root), do: Mix.raise("Project directory already exists: #{root}")

    Mix.Task.reenable("new")
    Mix.Tasks.New.run([root, "--app", config[:name], "--sup"])

    created =
      [
        write_elixir(Path.join(root, "mix.exs"), mix_exs(config)),
        write_elixir(Path.join(root, "config/config.exs"), app_config(config)),
        write(Path.join(root, "README.md"), project_readme(config)),
        write(Path.join(root, "LICENSE"), license(config))
      ] ++ network_files(root, config)

    %{name: config[:name], root: root, config: config, created: created}
  end

  defp prompt(config) do
    if config[:interactive] do
      config
      |> ask(:name, "App name", &identity/1)
      |> ask(:otp_version, "Erlang/OTP version", &identity/1)
      |> ask_bool(:jit, "Enable the Arm32 JIT?")
      |> ask(:dest, "SD card path", &identity/1)
      |> ask_bool(:network, "Generate network configuration?")
      |> prompt_network()
    else
      config
    end
  end

  defp prompt_network(config) do
    if config[:network] do
      config
      |> ask_bool(:wifi, "Use Wi-Fi?")
      |> prompt_wifi()
      |> ask_bool(:grisp_io, "Enable GRiSP.io integration?")
      |> prompt_grisp_io()
      |> ask_bool(:epmd, "Enable distributed Erlang?")
      |> prompt_epmd()
    else
      config
    end
  end

  defp prompt_wifi(config) do
    if config[:wifi] do
      config |> ask(:ssid, "Wi-Fi SSID", &identity/1) |> ask(:psk, "Wi-Fi password", &identity/1)
    else
      config
    end
  end

  defp prompt_grisp_io(config) do
    if config[:grisp_io] do
      config |> ask_bool(:grisp_io_linking, "Link a GRiSP2 board?") |> maybe_ask_token()
    else
      config
    end
  end

  defp maybe_ask_token(config) do
    if config[:grisp_io_linking],
      do: ask(config, :token, "Device linking token", &String.trim/1),
      else: config
  end

  defp prompt_epmd(config) do
    if config[:epmd], do: ask(config, :cookie, "Erlang cookie", &identity/1), else: config
  end

  defp ask(config, key, label, normalize) do
    default = config[key]
    answer = Mix.shell().prompt("#{label} [#{default || ""}]: ") |> String.trim()
    Keyword.put(config, key, if(answer == "", do: default, else: normalize.(answer)))
  end

  defp ask_bool(config, key, label) do
    default = config[key]
    hint = if default, do: "Y/n", else: "y/N"
    answer = Mix.shell().prompt("#{label} [#{hint}]: ") |> String.trim() |> String.downcase()

    value =
      case answer do
        "" -> default
        value when value in ["y", "yes", "true"] -> true
        value when value in ["n", "no", "false"] -> false
        _ -> Mix.raise("Expected yes or no")
      end

    Keyword.put(config, key, value)
  end

  defp validate!(config) do
    unless config[:name] =~ ~r/^[a-z][a-z0-9_]*$/ do
      Mix.raise("Application name must contain lowercase letters, numbers, and underscores")
    end

    if config[:wifi] and not config[:network], do: Mix.raise("--wifi requires --network")

    if (config[:ssid] || config[:psk]) && not config[:wifi],
      do: Mix.raise("--ssid and --psk require --wifi")

    if config[:grisp_io] and not config[:network], do: Mix.raise("--grisp-io requires --network")

    if config[:grisp_io_linking] and not config[:grisp_io],
      do: Mix.raise("--grisp-io-linking requires --grisp-io")

    if config[:token] && not config[:grisp_io_linking],
      do: Mix.raise("--token requires --grisp-io-linking")

    if config[:epmd] and not config[:network], do: Mix.raise("--epmd requires --network")
  end

  defp network_files(root, config) do
    if config[:network] do
      base = Path.join(root, "grisp/grisp2/common/deploy/files")
      files = [write(Path.join(base, "grisp.ini.mustache"), grisp_ini(config))]

      files =
        if config[:wifi],
          do: files ++ [write(Path.join(base, "wpa_supplicant.conf"), wpa(config))],
          else: files

      if config[:grisp_io],
        do: files,
        else: files ++ [write(Path.join(base, "erl_inetrc"), inetrc())]
    else
      []
    end
  end

  defp write(path, contents) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end

  defp write_elixir(path, contents) do
    formatted = contents |> Code.format_string!() |> IO.iodata_to_binary()
    write(path, formatted <> "\n")
  end

  defp mix_exs(config) do
    module = Macro.camelize(config[:name])
    included_epmd = if config[:epmd], do: ", included_applications: [:epmd]", else: ""

    epmd_dep =
      if config[:epmd],
        do:
          "\n      {:epmd, git: \"https://github.com/erlang/epmd\", ref: \"4d1a59\", runtime: false},",
        else: ""

    grisp_io_deps =
      if config[:grisp_io],
        do:
          "\n      {:certifi, \">= 0.0.0\"},\n      {:grisp_cryptoauth, \">= 0.0.0\"},\n      {:grisp_updater_grisp2, \">= 0.0.0\"},\n      {:grisp_connect, \">= 0.0.0\"},",
        else: ""

    """
    defmodule #{module}.MixProject do
      use Mix.Project

      def project do
        [
          app: :#{config[:name]},
          version: "0.1.0",
          elixir: "~> 1.20",
          description: #{inspect(config[:desc])},
          package: [
            licenses: ["Apache-2.0"],
            maintainers: [#{inspect("#{config[:author_name]} <#{config[:author_email]}>")}]
          ],
          start_permanent: Mix.env() == :prod,
          deps: deps(),
          grisp: grisp(),
          releases: releases()
        ]
      end

      def application do
        [extra_applications: [:logger]#{included_epmd}, mod: {#{module}.Application, []}]
      end

      defp deps do
        [#{epmd_dep}#{grisp_io_deps}
          {:grisp, "~> 2.12"},
          {:mix_grisp, "~> 0.2", runtime: false}
        ]
      end

      defp grisp do
        [
          platform: :grisp2,
          otp: [version: #{inspect(config[:otp_version])}, jit: #{config[:jit]}],
          deploy: [destination: #{inspect(config[:dest])}]
        ]
      end

      defp releases do
        [
          #{config[:name]}: [
            overwrite: true,
            cookie: #{inspect(config[:cookie])},
            include_erts: &MixGrisp.Release.erts/0,
            steps: [&MixGrisp.Release.init/1, :assemble],
            include_executables_for: [],
            strip_beams: Mix.env() == :prod
          ]
        ]
      end
    end
    """
  end

  defp app_config(config) do
    linking =
      if config[:token], do: "\n  device_linking_token: #{inspect(config[:token])},", else: ""

    base = "import Config\n"

    if config[:grisp_io] do
      base <>
        """

        config :grisp_keychain, api_module: :grisp_cryptoauth
        config :grisp_cryptoauth, tls_server_trusted_certs_cb: {:certifi, :cacerts, []}
        config :grisp_connect,#{linking}
          logger: []
        config :grisp_updater,
          system: {:grisp_updater_grisp2, %{}},
          sources: [
            {:grisp_updater_tarball, %{}},
            {:grisp_updater_http, %{backend: {:grisp_updater_grisp2, %{}}}}
          ]
        """
    else
      base
    end
  end

  defp grisp_ini(config) do
    wpa = if config[:wifi], do: "wpa=wpa_supplicant.conf\n", else: ""

    dist =
      if config[:epmd],
        do:
          " -kernel inetrc \"./erl_inetrc\" -internal_epmd epmd_sup -sname #{config[:name]} -setcookie #{config[:cookie]}",
        else: ""

    """
    [erlang]
    args = erl.rtems -C multi_time_warp -fnu -- -mode embedded -home . -pa . -root {{release_name}} -bindir {{release_name}}/erts-{{erts_vsn}}/bin -boot {{release_name}}/releases/{{release_version}}/start -boot_var RELEASE_LIB {{release_name}}/lib -config {{release_name}}/releases/{{release_version}}/sys.config#{dist} -user elixir -extra +iex --no-halt
    shell = none

    [network]
    ip_self=dhcp
    wlan=enable
    #{wpa}hostname=GRISP_HOSTNAME
    """
  end

  defp wpa(config),
    do:
      "network={\n    ssid=#{inspect(config[:ssid] || "WLAN_SSID")}\n    key_mgmt=WPA-PSK\n    psk=#{inspect(config[:psk] || "WLAN_PASSWORD")}\n}\n"

  defp inetrc do
    """
    {hosts_file, ""}.
    {cache_size, 0}.
    {lookup, [file, dns]}.
    """
  end

  defp project_readme(config) do
    """
    # #{config[:name]}

    #{config[:desc]}

    ## Build

        mix compile

    ## Deploy

        mix grisp.deploy --relname #{config[:name]} --relvsn 0.1.0
    """
  end

  defp license(config) do
    """
    Copyright #{config[:copyright_year]}, #{config[:author_name]} <#{config[:author_email]}>.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
    """
  end

  defp identity(value), do: value
end
