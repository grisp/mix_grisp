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
    supplied = options |> Keyword.keys() |> MapSet.new()

    config =
      options
      |> Keyword.merge(@defaults, fn _key, supplied, _default -> supplied end)
      |> Keyword.update!(:copyright_year, &(&1 || Integer.to_string(Date.utc_today().year)))
      |> prompt(supplied)

    validate!(config)
    root = Path.expand(config[:name])
    project_exists? = File.exists?(root)

    if project_exists? do
      confirm_existing!(root, config[:interactive])
    else
      Mix.Task.reenable("new")
      Mix.Tasks.New.run([root, "--app", config[:name], "--sup"])
    end

    created =
      [
        write_elixir(Path.join(root, "mix.exs"), mix_exs(config), project_exists?),
        write_elixir(
          Path.join(root, "config/config.exs"),
          app_config(config),
          project_exists?
        ),
        write(Path.join(root, "README.md"), project_readme(config), project_exists?),
        write(Path.join(root, "LICENSE"), license(config), project_exists?)
      ] ++ network_files(root, config, project_exists?)

    created = Enum.reject(created, &is_nil/1)

    if project_exists? do
      Mix.shell().info(
        "The project directory already existed; existing files were not overwritten. " <>
          "Review the project configuration before continuing."
      )
    end

    %{name: config[:name], root: root, config: config, created: created}
  end

  defp prompt(config, supplied) do
    if config[:interactive] do
      config
      |> ask_valid_name_unless_supplied(supplied)
      |> ask_unless_supplied(supplied, :otp_version, "Erlang/OTP version", &identity/1)
      |> ask_bool_unless_supplied(supplied, :jit, "Enable the Arm32 JIT patches?")
      |> ask_unless_supplied(supplied, :dest, "SD card path", &identity/1)
      |> ask_bool_unless_supplied(supplied, :network, "Generate network configuration?")
      |> prompt_network(supplied)
    else
      config
    end
  end

  defp prompt_network(config, supplied) do
    if config[:network] do
      config
      |> ask_bool_unless_supplied(supplied, :wifi, "Use Wi-Fi?")
      |> prompt_wifi(supplied)
      |> ask_bool_unless_supplied(supplied, :grisp_io, "Enable GRiSP.io integration?")
      |> prompt_grisp_io(supplied)
      |> ask_bool_unless_supplied(supplied, :epmd, "Enable distributed Erlang?")
      |> prompt_epmd(supplied)
    else
      config
    end
  end

  defp prompt_wifi(config, supplied) do
    if config[:wifi] do
      config
      |> ask_unless_supplied(supplied, :ssid, "Wi-Fi SSID", &identity/1)
      |> ask_unless_supplied(supplied, :psk, "Wi-Fi password", &identity/1)
    else
      config
    end
  end

  defp prompt_grisp_io(config, supplied) do
    if config[:grisp_io] do
      config
      |> ask_bool_unless_supplied(supplied, :grisp_io_linking, "Link a GRiSP2 board?")
      |> maybe_ask_token(supplied)
    else
      config
    end
  end

  defp maybe_ask_token(config, supplied) do
    if config[:grisp_io_linking],
      do: ask_unless_supplied(config, supplied, :token, "Device linking token", &String.trim/1),
      else: config
  end

  defp prompt_epmd(config, supplied) do
    if config[:epmd],
      do: ask_unless_supplied(config, supplied, :cookie, "Erlang cookie", &identity/1),
      else: config
  end

  defp ask_unless_supplied(config, supplied, key, label, normalize) do
    if MapSet.member?(supplied, key), do: config, else: ask(config, key, label, normalize)
  end

  defp ask_bool_unless_supplied(config, supplied, key, label) do
    if MapSet.member?(supplied, key), do: config, else: ask_bool(config, key, label)
  end

  defp ask_valid_name_unless_supplied(config, supplied) do
    if MapSet.member?(supplied, :name) and valid_name?(config[:name]) do
      config
    else
      ask_valid_name(config)
    end
  end

  defp ask_valid_name(config) do
    config = ask(config, :name, "App name", &identity/1)

    if valid_name?(config[:name]) do
      config
    else
      Mix.shell().error(name_error())
      ask_valid_name(Keyword.put(config, :name, nil))
    end
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

    case answer do
      "" ->
        Keyword.put(config, key, default)

      value when value in ["y", "yes", "true"] ->
        Keyword.put(config, key, true)

      value when value in ["n", "no", "false"] ->
        Keyword.put(config, key, false)

      _ ->
        Mix.shell().error("Expected yes or no")
        ask_bool(config, key, label)
    end
  end

  defp validate!(config) do
    unless valid_name?(config[:name]), do: Mix.raise(name_error())

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

  defp network_files(root, config, preserve?) do
    if config[:network] do
      base = Path.join(root, "grisp/grisp2/common/deploy/files")
      files = [write(Path.join(base, "grisp.ini.mustache"), grisp_ini(config), preserve?)]

      files =
        if config[:wifi],
          do:
            files ++
              [write(Path.join(base, "wpa_supplicant.conf"), wpa(config), preserve?)],
          else: files

      files ++ [write(Path.join(base, "erl_inetrc"), inetrc(), preserve?)]
    else
      []
    end
  end

  defp write(path, contents, preserve?)

  defp write(path, contents, true) when is_binary(path) do
    if File.exists?(path), do: nil, else: write(path, contents, false)
  end

  defp write(path, contents, false) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
    path
  end

  defp write_elixir(path, contents, preserve?) do
    formatted = contents |> Code.format_string!() |> IO.iodata_to_binary()
    write(path, formatted <> "\n", preserve?)
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
          "\n      {:certifi, \">= 0.0.0\"},\n      {:grisp_cryptoauth, \"~> 2.6\"},\n      {:grisp_updater_grisp2, \"~> 1.0\", runtime: false},\n      {:grisp_connect, \"~> 3.0.0\"},",
        else: ""

    grisp_dep =
      if config[:grisp_io],
        do: "{:grisp, \"~> 2.12\", override: true}",
        else: "{:grisp, \"~> 2.12\"}"

    grisp_io_release_apps =
      if config[:grisp_io],
        do: "\n            applications: [sasl: :permanent, grisp_updater_grisp2: :load],",
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
          #{grisp_dep},
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
            cookie: #{inspect(config[:cookie])},#{grisp_io_release_apps}
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
    connect_config =
      if config[:token] do
        "config :grisp_connect,\n  device_linking_token: #{inspect(config[:token])}\n"
      else
        ""
      end

    base = "import Config\n"

    if config[:grisp_io] do
      rendered =
        "config/grisp_io.exs"
        |> template()
        |> String.replace("__GRISP_CONNECT_CONFIG__", connect_config)

      base <> "\n" <> rendered
    else
      base
    end
  end

  defp grisp_ini(config) do
    wifi = if config[:wifi], do: "wlan=enable\nwpa=wpa_supplicant.conf\n", else: ""
    grisp_io = if config[:grisp_io], do: " -kernel logger_level notice", else: ""

    epmd =
      if config[:epmd],
        do: " -internal_epmd epmd_sup -sname #{config[:name]} -setcookie #{config[:cookie]}",
        else: ""

    "grisp/grisp2/common/deploy/files/grisp.ini.mustache"
    |> template()
    |> String.replace("__EPMD_ARGS__", epmd)
    |> String.replace("__GRISP_IO_ARGS__", grisp_io)
    |> String.replace("__WIFI_CONFIG__", wifi)
  end

  defp wpa(config) do
    "grisp/grisp2/common/deploy/files/wpa_supplicant.conf"
    |> template()
    |> String.replace("__WLAN_SSID__", inspect(config[:ssid] || "WLAN_SSID"))
    |> String.replace("__WLAN_PASSWORD__", inspect(config[:psk] || "WLAN_PASSWORD"))
  end

  defp inetrc, do: template("grisp/grisp2/common/deploy/files/erl_inetrc")

  defp template(relative_path) do
    :mix_grisp
    |> Application.app_dir("priv/templates")
    |> Path.join(relative_path)
    |> File.read!()
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

  defp valid_name?(name) when is_binary(name), do: Regex.match?(~r/^[a-z][a-z0-9_]*$/, name)
  defp valid_name?(_name), do: false

  defp name_error,
    do: "Application name must contain lowercase letters, numbers, and underscores"

  defp confirm_existing!(root, false), do: Mix.raise("Project directory already exists: #{root}")

  defp confirm_existing!(root, true) do
    answer =
      Mix.shell().prompt(
        "Project directory #{root} already exists. Continue without overwriting files? [y/N]: "
      )
      |> String.trim()
      |> String.downcase()

    case answer do
      value when value in ["y", "yes", "true"] ->
        :ok

      value when value in ["", "n", "no", "false"] ->
        Mix.raise("Project directory already exists: #{root}")

      _ ->
        Mix.shell().error("Expected yes or no")
        confirm_existing!(root, true)
    end
  end
end
