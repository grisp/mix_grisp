config :logger,
  level: :notice

config :grisp_keychain,
  api_module: :grisp_cryptoauth

config :grisp_cryptoauth,
  tls_server_trusted_certs_cb: {:certifi, :cacerts, []}

__GRISP_CONNECT_CONFIG__

config :grisp_updater,
  system: {:grisp_updater_grisp2, %{}},
  sources: [
    {:grisp_updater_tarball, %{}},
    {:grisp_updater_http, %{backend: {:grisp_updater_grisp2, %{}}}}
  ]
