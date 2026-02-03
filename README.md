# GRiSP Mix Plugin

A Mix plugin for building and deploying Elixir applications to [GRiSP boards][grisp]. This tool simplifies the process of creating embedded applications that run on GRiSP hardware.

## What is GRiSP?

[GRiSP][grisp] is a development board that runs Erlang/Elixir applications on bare metal using RTEMS (Real-Time Executive for Multiprocessor Systems). It's perfect for IoT projects, embedded systems, and real-time applications.

## Prerequisites

Before you begin, make sure you have:

- **Elixir 1.17+** and **Erlang/OTP 27+** installed
- **Mix** (comes with Elixir)
- A **GRiSP board** and **SD card** for deployment
- Basic familiarity with Elixir and Mix

## Quick Start

### 1. Create a New Project

```bash
mix new my_grisp_app --module MyGrispApp
cd my_grisp_app
```

### 2. Add Dependencies

Add the required dependencies to your `mix.exs`:

```elixir
def deps do
  [
    {:grisp, "~> 2.9"},
    {:mix_grisp, "~> 0.2.0", only: :dev}
  ]
end
```

### 3. Configure Your Project

Update your `mix.exs` with the GRiSP configuration:

```elixir
def project do
  [
    app: :my_grisp_app,
    version: "0.1.0",
    elixir: "~> 1.17",
    start_permanent: Mix.env() == :prod,
    deps: deps(),
    grisp: grisp(),
    releases: releases()
  ]
end

defp deps do
  [
    {:grisp, "~> 2.9"},
    {:mix_grisp, "~> 0.2.0", only: :dev}
  ]
end

def grisp do
  [
    otp: [version: "27"],
    deploy: [
      # Uncomment and configure these for direct SD card deployment:
      # pre_script: "rm -rf /Volumes/GRISP/*",
      # destination: "tmp/grisp"
      # post_script: "diskutil unmount /Volumes/GRISP",
    ]
  ]
end

def releases do
  [
    my_grisp_app: [
      overwrite: true,
      cookie: "grisp",
      include_erts: &MixGrisp.Release.erts/0,
      steps: [&MixGrisp.Release.init/1, :assemble],
      include_executables_for: [],
      strip_beams: Mix.env() == :prod
    ]
  ]
end
```

### 4. Create Configuration Files

Create the required configuration files for your GRiSP board:

#### Network Configuration

Create `grisp/grisp2/common/deploy/files/grisp.ini.mustache`:

```ini
[erlang]
args = erl.rtems -C multi_time_warp -fnu -- -mode embedded -home . -pa . -root {{release_name}} -bindir {{release_name}}/erts-{{erts_vsn}}/bin -boot {{release_name}}/releases/{{release_version}}/start -boot_var RELEASE_LIB {{release_name}}/lib  -config {{release_name}}/releases/{{release_version}}/sys.config -user elixir -run elixir start_cli -extra --no-halt
shell = none

[network]
ip_self=dhcp
wlan=enable
hostname=my-grisp-board
wpa=wpa_supplicant.conf
```

Create `grisp/grisp2/common/deploy/files/wpa_supplicant.conf`:

```conf
network={
    ssid="YOUR_WIFI_SSID"
    key_mgmt=WPA-PSK
    psk="YOUR_WIFI_PASSWORD"
}
```

**Important:** Replace `YOUR_WIFI_SSID` and `YOUR_WIFI_PASSWORD` with your actual WiFi credentials, and change `my-grisp-board` to your desired hostname.

### 5. Install Dependencies

```bash
mix deps.get
```

### 6. Deploy to GRiSP

```bash
mix grisp.deploy
```

## Configuration Explained

### GRiSP Configuration

The `grisp()` function in your `mix.exs` configures:

- **OTP Version**: Must match your local Erlang version (check with `erl -eval 'io:format("~s~n", [erlang:system_info(otp_release)]), halt().'`)
- **Deploy Options**: 
  - `pre_script`: Commands to run before deployment (e.g., clearing SD card)
  - `destination`: Where to deploy (local path or SD card mount point)
  - `post_script`: Commands to run after deployment (e.g., unmounting SD card)

### Release Configuration

The `releases()` function configures how your application is packaged:

- **Cookie**: Used for Erlang distribution (keep as "grisp" unless you need custom distribution)
- **Include ERTS**: Includes the Erlang runtime system
- **Steps**: Custom build steps for GRiSP compatibility

## Deployment Options

### Local Development
For testing, deploy to a local directory:

```elixir
def grisp do
  [
    otp: [version: "27"],
    deploy: [
      destination: "tmp/grisp"
    ]
  ]
end
```

### Direct to SD Card
For production deployment, configure your SD card mount point:

```elixir
def grisp do
  [
    otp: [version: "27"],
    deploy: [
      pre_script: "rm -rf /Volumes/GRISP/*",
      destination: "/Volumes/GRISP",
      post_script: "diskutil unmount /Volumes/GRISP"
    ]
  ]
end
```

**Note:** Adjust the mount point (`/Volumes/GRISP`) to match your system.

## Enabling Erlang Distribution

To enable distributed Erlang on your GRiSP board:

### 1. Add EPMD Dependency

```elixir
def deps do
  [
    {:grisp, "~> 2.9"},
    {:mix_grisp, "~> 0.2.0", only: :dev},
    {:epmd, git: "https://github.com/erlang/epmd", ref: "4d1a59", runtime: false}
  ]
end
```

### 2. Include EPMD in Your Application

```elixir
def application do
  [
    extra_applications: [:logger],
    included_applications: [:epmd]
  ]
end
```

### 3. Update GRiSP Configuration

Modify your `grisp.ini.mustache` to include distribution flags. Your `args` should terminate with the following flags, choose a nodename and cookie of your liking:

```ini
[erlang]
args = erl.rtems -C multi_time_warp -fnu -- -mode embedded -home . -pa . -root {{release_name}} -bindir {{release_name}}/erts-{{erts_vsn}}/bin -boot {{release_name}}/releases/{{release_version}}/start -boot_var RELEASE_LIB {{release_name}}/lib  -config {{release_name}}/releases/{{release_version}}/sys.config -user elixir -run elixir start_cli -kernel inetrc "./erl_inetrc" -internal_epmd epmd_sup -sname grisp -setcookie grisp -extra --no-halt
shell = none
```

**Note:** Replace `mynode` with your desired node name and `mycookie` with your desired cookie.

## Troubleshooting

### Common Issues

#### BEAM File Version Mismatch
**Error:** "This BEAM file was compiled for a later version of the run-time system"

**Solution:** Clean and rebuild:
```bash
rm -rf _build deps
mix deps.get
mix grisp.deploy
```

#### OTP Version Mismatch
**Error:** Deployment fails with version-related errors

**Solution:** Ensure your local Erlang version matches the configured version:
```bash
erl -eval 'io:format("~s~n", [erlang:system_info(otp_release)]), halt().'
```

Update the `otp: [version: "XX"]` in your `grisp()` configuration to match.

#### SD Card Not Found
**Error:** Deployment fails when trying to write to SD card

**Solution:** 
1. Check your SD card mount point
2. Ensure the card is properly mounted
3. Verify write permissions

#### WiFi Connection Issues
**Error:** GRiSP board doesn't connect to WiFi

**Solution:**
1. Verify SSID and password in `wpa_supplicant.conf`
2. Check WiFi network compatibility (WPA-PSK)
3. Ensure the network is in range

### Getting Help

- Check the [GRiSP documentation][grisp]
- Review the [GRiSP wiki](https://github.com/grisp/grisp/wiki)
- Ensure your Erlang/Elixir versions are compatible

## What's Next?

After successful deployment:

1. **Monitor your application** using the GRiSP console
2. **Connect via WiFi** using the configured hostname
3. **Develop your application** by adding modules to `lib/`
4. **Test Erlang distribution** if enabled
5. **Deploy updates** using `mix grisp.deploy`

## Contributing

Found an issue or have a suggestion? Please [open an issue](https://github.com/grisp/mix_grisp/issues) or submit a pull request.

[grisp]: https://www.grisp.org

