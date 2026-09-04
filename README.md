# GRiSP Mix plug-in

Mix plug-in for building and deploying Elixir applications to a [GRiSP board][grisp].

## Requirements

- Elixir 1.20 or later
- A local Erlang/OTP installation whose major version matches the configured
  target OTP version
- A supported GRiSP board and SD card

The examples below use Erlang/OTP 29 and a GRiSP 2 board. If you select another
supported OTP version, use that same major OTP version on the development host
when compiling and deploying the application.

## Installation

Add `grisp` and `mix_grisp` to the dependencies in `mix.exs`:

```elixir
defp deps do
  [
    {:grisp, "~> 2.12"},
    {:mix_grisp, "~> 0.2.0", only: :dev}
  ]
end
```

## Creating and configuring a project

Create a standard Mix project:

```console
mix new testex --module TestEx
cd testex
```

Add the GRiSP and release configuration to the project module in `mix.exs`:

```elixir
def project do
  [
    app: :testex,
    version: "0.1.0",
    elixir: "~> 1.20",
    start_permanent: Mix.env() == :prod,
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
      # Use a local directory while testing the deployment:
      destination: "tmp/grisp_sd",

      # To deploy directly to a mounted SD card, replace `destination` with its
      # mount path. Optional scripts can prepare and unmount the card:
      # pre_script: "rm -rf /Volumes/GRISP/*",
      # destination: "/Volumes/GRISP",
      # post_script: "diskutil unmount /Volumes/GRISP"
    ]
  ]
end

defp releases do
  [
    testex: [
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

The `:platform` option defaults to `:grisp2`. The `:jit` option controls whether
the available Arm32 JIT patches are applied to the selected OTP build.

Replace the example release cookie before enabling Erlang distribution. Use the
same cookie wherever the node cookie is configured.

## Network configuration

Mix releases use `$RELEASE_LIB` in their boot files. Add an overlay file at
`grisp/grisp2/common/deploy/files/grisp.ini.mustache` in your project so the
GRiSP runtime can expand that variable. The `-boot_var RELEASE_LIB
{{release_name}}/lib` argument is required; omitting it causes boot to terminate
with `cannot expand $RELEASE_LIB in bootfile`.

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

Replace `GRISP_HOSTNAME` with the desired board hostname. For Wi-Fi, also add
`grisp/grisp2/common/deploy/files/wpa_supplicant.conf`:

```ini
network={
    ssid="WLAN_SSID"
    key_mgmt=WPA-PSK
    psk="WLAN_PASSWORD"
}
```

Replace `WLAN_SSID` and `WLAN_PASSWORD` with the Wi-Fi network credentials. Do
not commit real credentials to source control.

See the [GRiSP networking guide][networking] for the available `grisp.ini`
settings.

## Deploying

Fetch the dependencies:

```console
mix deps.get
```

Confirm that the local OTP major version matches `grisp[:otp][:version]`:

```console
erl -noshell -eval 'io:format("~s~n", [erlang:system_info(otp_release)]), halt().'
```

Deploy the application:

```console
mix grisp.deploy
```

Without an explicit destination, `mix_grisp` writes the deployment to
`tmp/grisp_sd`. Set `grisp[:deploy][:destination]` to the SD card mount point to
deploy directly to the card.

## Enabling Erlang distribution

GRiSP can run Erlang distribution with an internal EPMD implementation.

Add the tested EPMD revision to the project dependencies. `runtime: false`
prevents Mix from starting it as a regular OTP application on the development
host:

```elixir
{:epmd,
 git: "https://github.com/erlang/epmd",
 ref: "4d1a59",
 runtime: false}
```

Include EPMD in the release so its modules are available on the board:

```elixir
def application do
  [
    extra_applications: [:logger],
    included_applications: [:epmd]
  ]
end
```

Insert the distribution options in the `[erlang]` `args` value in
`grisp.ini.mustache` before `-user elixir -extra +iex --no-halt`:

```text
-internal_epmd epmd_sup -sname mynode -setcookie replace_with_a_long_random_cookie
```

Choose a unique node name and use the same cookie configured for the release.
Keep the existing `-kernel inetrc "./erl_inetrc"` option in the argument list.

## Troubleshooting

### Cannot expand `$RELEASE_LIB` in bootfile

The GRiSP boot configuration is missing the Mix release library path. Add the
project `grisp.ini.mustache` overlay shown under
[Network configuration](#network-configuration), redeploy, and verify that the
generated `grisp.ini` contains:

```text
-boot_var RELEASE_LIB <release-name>/lib
```

### This BEAM file was compiled for a later version of the runtime system

The project or one of its dependencies was compiled with a different OTP major
version. Switch the local Erlang installation to the configured target version,
then rebuild and deploy:

```console
mix clean
mix deps.clean --all --build
mix deps.get
mix grisp.deploy
```

[grisp]: https://www.grisp.org
[networking]: https://github.com/grisp/grisp/wiki/Connecting-over-WiFI-and-Ethernet#grisp-ini
