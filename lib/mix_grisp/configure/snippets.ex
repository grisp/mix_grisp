defmodule MixGrisp.Configure.Snippets do
  @moduledoc false

  def grisp_function(config) do
    """
      def grisp do
        [
          otp: [version: "#{config.otp_version}"],
          deploy: [
            # pre_script: "rm -rf /Volumes/GRISP/*",
            # destination: "tmp/grisp"
            # post_script: "diskutil unmount /Volumes/GRISP",
          ]
        ]
      end
    """
  end

  def releases_function(config) do
    """
      def releases do
        [
          {:#{config.name},
            [
              overwrite: true,
              cookie: "#{config.cookie || "grisp"}",
              include_erts: &MixGrisp.Release.erts/0,
              steps: [&MixGrisp.Release.init/1, :assemble],
              include_executables_for: [],
              strip_beams: Mix.env() == :prod
            ]}
        ]
      end
    """
  end

  def epmd_dependency do
    ~s({:epmd, git: "https://github.com/erlang/epmd", ref: "4d1a59", runtime: false})
  end

  def epmd_application_manual_step do
    """
    Add epmd to your application config so its modules are available at runtime:
      extra_applications: [:logger]
      included_applications: [:epmd]
    """
  end

  def grisp_io_dependencies_manual_step do
    """
    Add the GRiSP.io runtime dependencies to deps/0 with versions that match your GRiSP stack:
      {:certifi, ...}
      {:grisp_cryptoauth, ...}
      {:grisp_updater_grisp2, ...}
      {:grisp_connect, ...}
    """
  end

  def grisp_io_config(config) do
    linking_line =
      if config.grisp_io_linking and config.token do
        ~s(  device_linking_token: "#{config.token}",\n)
      else
        ""
      end

    """
    config :grisp_keychain,
      api_module: :grisp_cryptoauth

    config :grisp_cryptoauth,
      tls_server_trusted_certs_cb: {:certifi, :cacerts, []}

    config :grisp_connect,
    #{linking_line}  logger: []

    config :grisp_updater,
      system: {:grisp_updater_grisp2, %{}},
      sources: [
        {:grisp_updater_tarball, %{}},
        {:grisp_updater_http, %{backend: {:grisp_updater_grisp2, %{}}}}
      ]

    config :kernel,
      logger_level: :notice
    """
  end

  def grisp_io_config_manual_step(config) do
    """
    Add the GRiSP.io runtime config to config/config.exs:

    #{grisp_io_config(config)}
    """
  end
end
