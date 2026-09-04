# mix_grisp

Mix tooling for building, deploying, and updating Elixir applications on
[GRiSP boards][grisp]. It provides the same GRiSP workflows as
`rebar3_grisp`, adapted to Mix releases and Elixir configuration.

Run `mix help grisp.TASK` for task-specific help.

## Requirements

- Elixir 1.20 or later
- A local Erlang/OTP installation whose major version matches the target OTP
- A GRiSP 2 board and SD card
- A GRiSP toolchain or Docker when building OTP, eMMC images, or bootloaders

## Installation

Add GRiSP and this build-time plugin to `mix.exs`:

```elixir
defp deps do
  [
    {:grisp, "~> 2.12"},
    {:mix_grisp, "~> 0.2", runtime: false}
  ]
end
```

Fetch dependencies with `mix deps.get`. Print the installed plugin and library
versions with:

```console
mix grisp.version
```

## Create a new application

The configure task creates a supervised Mix application, release and GRiSP
configuration, and optional networking files:

```console
mix grisp.configure
```

For non-interactive use:

```console
mix grisp.configure --no-interactive --name my_grisp_app \
  --network --wifi --ssid mywifi --psk wifipsk
```

Important options are `--name`, `--otp-version`, `--[no-]jit`, `--dest`,
`--network`, `--wifi`, `--ssid`, `--psk`, `--grisp-io`,
`--grisp-io-linking`, `--token`, `--epmd`, and `--cookie`. Wi-Fi requires
networking; credentials require Wi-Fi; GRiSP.io and EPMD require networking.

## Configure an existing application

Add GRiSP and release configuration to the project keyword list:

```elixir
def project do
  [
    app: :my_app,
    version: "0.1.0",
    elixir: "~> 1.20",
    deps: deps(),
    grisp: grisp(),
    releases: releases()
  ]
end

defp grisp do
  [
    platform: :grisp2,
    otp: [version: "29", jit: true],
    deploy: [
      destination: "/path/to/SD-card",
      # pre_script: "rm -rf /path/to/SD-card/*",
      # post_script: "diskutil unmount /path/to/SD-card"
    ]
  ]
end

defp releases do
  [
    my_app: [
      overwrite: true,
      cookie: "replace_with_a_long_random_cookie",
      include_erts: &MixGrisp.Release.erts/0,
      steps: [&MixGrisp.Release.init/1, :assemble],
      include_executables_for: [],
      strip_beams: Mix.env() == :prod
    ]
  ]
end
```

`:platform` defaults to `:grisp2`. The configured OTP requirement selects a
pre-built package unless a `:build` section enables a custom build. Compile on
the development host with the same OTP major version as the target.

## Elixir shell and networking

Add `grisp/grisp2/common/deploy/files/grisp.ini.mustache`. Mix releases need
the `RELEASE_LIB` boot variable. Elixir also expects native UTF-8 filename
encoding, so `-fnu` must be passed to `erl.rtems`. To boot into IEx, use the
Elixir user driver and `+iex`; `-s elixir start_iex` is obsolete and fails on
current Elixir releases.

```ini
[erlang]
args = erl.rtems -C multi_time_warp -fnu -- -mode embedded -home . -pa . -root {{release_name}} -bindir {{release_name}}/erts-{{erts_vsn}}/bin -boot {{release_name}}/releases/{{release_version}}/start -boot_var RELEASE_LIB {{release_name}}/lib -config {{release_name}}/releases/{{release_version}}/sys.config -kernel inetrc "./erl_inetrc" -user elixir -extra +iex --no-halt
shell = none
on_exit = reboot
on_crash = reboot

[network]
ip_self=dhcp
wlan=enable
hostname=GRISP_HOSTNAME
wpa=wpa_supplicant.conf
```

For Wi-Fi, add `wpa_supplicant.conf` beside it:

```ini
network={
    ssid="WLAN_SSID"
    key_mgmt=WPA-PSK
    psk="WLAN_PASSWORD"
}
```

Do not commit real credentials. See the [GRiSP networking guide][networking].

## Deploy a release

Deploy to the configured destination:

```console
mix grisp.deploy
mix grisp.deploy --relname my_app --relvsn 0.1.0
mix grisp.deploy --destination /Volumes/GRISP --force
```

If more than one release is configured, `--relname` is required. Use `--tar`
to create `_grisp/deploy/grisp2.RELNAME.RELVSN.tar.gz` instead of copying to a
destination:

```console
mix grisp.deploy --tar
```

Options are `--relname/-n`, `--relvsn/-v`, `--tar/-t`,
`--destination/-d`, `--force/-f`, `--pre-script`, and `--post-script`.
Options after `--` are forwarded to `mix release`:

```console
mix grisp.deploy --tar -- --quiet
```

The task compiles with `GRISP=yes` and `GRISP_PLATFORM` set, resolves or reuses
the target OTP package, creates a Mix release with the target ERTS, and applies
all application `grisp/*/deploy` overlays.

## Generate GRiSP 2 firmware

The default command generates a system-partition firmware under
`_grisp/firmware`:

```console
mix grisp.firmware
```

Available outputs are:

- system firmware (`.sys.gz`), enabled by default and disabled with
  `--no-system`;
- an eMMC image (`.emmc.gz`) with `--image`;
- bootloader firmware (`.boot.gz`) with `--bootloader`.

Examples:

```console
mix grisp.firmware --relname my_app --relvsn 0.1.0
mix grisp.firmware --image --bootloader --force --refresh
mix grisp.firmware --image --no-truncate
mix grisp.firmware --bundle path/to/release.tar.gz
```

Other options are `--[no-]compress`, `--quiet`, and all release selection
options. A bundle is created through `grisp.deploy --tar` when not supplied;
`--refresh` recreates it. Image and bootloader generation requires a toolchain.

To install firmware, copy it to the GRiSP SD card, unmount the card, open the
serial console, insert the card, reset, and interrupt barebox. Write system
firmware to the active partition (`/dev/mmc1.0` or `/dev/mmc1.1`):

```text
uncompress /mnt/mmc/grisp2.RELNAME.RELVSN.sys.gz /dev/mmc1.0
```

Write an eMMC image or bootloader to `/dev/mmc1`:

```text
uncompress /mnt/mmc/grisp2.RELNAME.RELVSN.emmc.gz /dev/mmc1
uncompress /mnt/mmc/grisp2.RELNAME.RELVSN.boot.gz /dev/mmc1
```

A truncated image contains only the first system partition. Set the active
system to `0` before booting it. Writing a system firmware to the inactive A/B
partition does not change what the board currently boots.

## Build a software update package

Create `_grisp/update/grisp2.RELNAME.RELVSN.tar`:

```console
mix grisp.pack
mix grisp.pack --with-bootloader
mix grisp.pack --refresh --force
mix grisp.pack --key private_key.pem
```

The task reuses or generates firmware automatically. Options include
`--system`, `--bootloader`, `--block-size`, `--key`, `--with-bootloader`,
`--refresh`, `--force`, and `--quiet`. If explicit firmware is used, an
explicit bootloader must be accompanied by an explicit system firmware.

For A/B updates, include `grisp_updater_grisp2` and configure `:grisp_updater`:

```elixir
config :grisp_updater,
  signature_check: true,
  signature_certificates: {:priv, :my_app, "certificates/updates"},
  system: {:grisp_updater_grisp2, %{}},
  sources: [
    {:grisp_updater_tarball, %{}},
    {:grisp_updater_http, %{backend: {:grisp_updater_grisp2, %{}}}}
  ]
```

Extract the package under `releases/RELNAME/RELVSN`, serve `releases` over
HTTP, then update and validate from IEx:

```elixir
:grisp_updater.update("http://HOST_IP:8000/RELNAME/RELVSN")
:grisp_updater.validate()
```

When signature checking is enabled, use `--key` and install the corresponding
public certificate in the configured directory.

## List pre-built packages

```console
mix grisp.package list
mix grisp.package list --type toolchain
mix grisp.package list --cached
mix grisp.package list --columns version,hash,url
```

Use `--platform` to override the configured platform. OTP columns are
`version`, `hash`, `name`, `size`, `etag`, `url`, and `last_modified`.
Toolchain results also provide `os`, `os_version`, `revision`, and `latest`.

## Build OTP for GRiSP

Custom drivers, NIFs, and GRiSP system changes require a custom OTP build. Add
a toolchain to the GRiSP configuration:

```elixir
defp grisp do
  [
    platform: :grisp2,
    otp: [version: "29", jit: true],
    build: [
      toolchain: [
        # Local installation takes precedence:
        directory: "/PATH/TO/grisp2-rtems-toolchain/rtems/VERSION/"
        # Or: docker: "grisp/grisp2-rtems-toolchain"
      ]
    ],
    deploy: [destination: "/PATH/TO/DESTINATION"]
  ]
end
```

`GRISP_TOOLCHAIN` overrides the configured directory. Build with:

```console
mix grisp.build
mix grisp.build --no-configure
mix grisp.build --clean
mix grisp.build --tar
mix grisp.build --update-prebuild
```

The installation is stored under `_grisp/otp/VERSION/install`. Reconfigure
after adding C sources; `--no-configure` can speed up rebuilds after ordinary
source changes.

## Bug reports

```console
mix grisp.report
mix grisp.report --tar
```

Reports are written under `_grisp/report`. Review them for private information
before sharing.

## Development checkouts

To test local branches, place both repositories in the consuming project's
`_checkouts` directory:

```console
git clone https://github.com/grisp/mix_grisp.git _checkouts/mix_grisp
git clone https://github.com/grisp/grisp_tools.git _checkouts/grisp_tools
```

Mix automatically gives checkout dependencies precedence over Hex packages.

## Troubleshooting

If boot fails with `cannot expand $RELEASE_LIB in bootfile`, ensure the
`-boot_var RELEASE_LIB {{release_name}}/lib` option is present. If BEAM files
were compiled for a later runtime, switch the development host to the target
OTP major and rebuild:

```console
mix clean
mix deps.clean --all --build
mix deps.get
mix grisp.deploy
```

[grisp]: https://www.grisp.org
[networking]: https://github.com/grisp/grisp/wiki/Connecting-over-WiFI-and-Ethernet#grisp-ini
