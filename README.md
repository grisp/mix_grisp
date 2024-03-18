# GRiSP Mix plug-in

Mix plug-in to build and deploy GRiSP applications for the [GRiSP board][grisp].

## Summary

The package can be installed by adding `mix_grisp` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:mix_grisp, "~> 0.2.0", only: :dev}
  ]
end
```

## New Project Step-By-Step

### Create New Project

Create a project using Elixir default project template:

    ```
    $ mix new testex --module TestEx
    $ cd testex
    ```

### Add Dependencies

Add the following dependencies in the project `mix.exs`:

    ```
        defp deps do
            [
                ...
                {:grisp, "~> 2.4"},
                {:mix_grisp, "~> 0.2.0", only: :dev},
            ]
        end
    ```

### Configure Grisp

Add the following configuration to your project:

    ```
        def project do
            [
                ...
                grisp: grisp(),
                releases: releases()
            ]
        end

        def grisp do
            [
                otp: [verson: "26"],
                deploy: [
                    # pre_script: "rm -rf /Volumes/GRISP/*",
                    # destination: "tmp/grisp"
                    # post_script: "diskutil unmount /Volumes/GRISP",
                ]
            ]
        end

        def releases do
            [
                {:myapp,
                    [
                        overwrite: true,
                        cookie: "grisp",
                        include_erts: &MixGrisp.Release.erts/0,
                        steps: [&MixGrisp.Release.init/1, :assemble],
                        include_executables_for: [],
                        strip_beams: Mix.env() == :prod
                    ]}
                ]
        end
    ```

You can uncomment the lines in the `deploy` list after setting the proper mount
point for your SD card if you want to deploy directly to it. The destination can be
a normal path if you want to deploy to a local directory.

Add the following boot configuration files after changing `GRISP_HOSTNAME` to
the hostname you want the grisp board to have, `WLAN_SSID` and `WLAN_PASSWORD`
to the ssid and password of the WiFi network the Grisp board should connect to.

    * `grisp/grisp2/common/deploy/files/grisp.ini.mustache`

        ```
        [erlang]
        args = erl.rtems -C multi_time_warp -- -mode embedded -home . -pa . -root {{release_name}} -bindir {{release_name}}/erts-{{erts_vsn}}/bin -boot {{release_name}}/releases/{{release_version}}/start -boot_var RELEASE_LIB {{release_name}}/lib  -config {{release_name}}/releases/{{release_version}}/sys.config -s elixir start_iex -extra --no-halt
        shell = none

        [network]
        ip_self=dhcp
        wlan=enable
        hostname=GRISP_HOSTNAME
        wpa=wpa_supplicant.conf
        ```


    * `grisp/grisp2/common/deploy/files/wpa_supplicant.conf`

        ```
        network={
            ssid="WLAN_SSID"
            key_mgmt=WPA-PSK
            psk="WLAN_PASSWORD"
        }
        ```

### Add Configuration

If not generated bu Mix template, add the file `config/config.exs`:

    ```
    import Config
    ```

### Check OTP Version

Verify that your default erlang version matches the one configured
(26 in the example).

This is required because the beam files are compiled locally and need to be
compiled by the same version of the VM.

### Get Dependencies

Get all the dependencies:

    ```
    $ mix deps.get
    ```

### Deploy The Project

To deploy, use the grisp command provided by `mix_grisp`:

    ```
    $ mix grisp.deploy
    ```

### Troubleshooting

#### This BEAM file was compiled for a later version of the run-time system

Some bema files were compiled with a newer version of OTP, delete `_build` and
`deps`, get the fresh dependencies (`mix deps.get`), and redeploy
(`mix grisp.deploy`).

[grisp]: https://www.grisp.org
