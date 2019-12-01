# GRiSP Mix plug-in

Mix plug-in to build and deploy GRiSP applications for the [GRiSP board][grisp].

## Summary

The package can be installed by adding `mix_grisp` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:mix_grisp, "~> 0.1.4", only: :dev}
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
                {:grisp, "~> 1.1"},
                {:mix_grisp, "~> 0.1.0", only: :dev},
            ]
        end
    ```


### Configure Grisp

Add the following configuration to your project:

    ```
        def project do
            [
                ...
                grisp: [
                    otp: [verson: "21.0"],
                    deploy: [
                        # pre_script: "rm -rf /Volumes/GRISP/*",
                        # destination: "/Volumes/GRISP",
                        # post_script: "diskutil unmount /Volumes/GRISP",
                    ]
                ],
            ]
        end
    ```

You can uncomment the lines in the `deploy` list after setting the proper mount
point for your SD card if you want to deploy directly to it. The destination can be
a normal path if you want to deploy to a local directory.

Add the following boot configuration files after changing `GRISP_HOSTNAME` to
the hostname you want the grisp board to have, `WLAN_SSID` and `WLAN_PASSWORD`
to the ssid and password of the WiFi network the Grisp board should connect to.

    * `grisp/grisp_base/files/grisp.ini.mustach`

        ```
        [boot]
        image_path = /media/mmcsd-0-0/{{release_name}}/erts-{{erts_vsn}}/bin/beam.bin

        [erlang]
        args = erl.rtems -- -mode embedded -home . -pa . -root {{release_name}} -boot {{release_name}}/releases/{{release_version}}/{{release_name}} -s elixir start_cli -noshell -user Elixir.IEx.CLI -extra --no-halt

        [network]
        ip_self=dhcp
        wlan=enable
        hostname=GRISP_HOSTNAME
        wpa=wpa_supplicant.conf
        ```


    * `grisp/grisp_base/files/wpa_supplicant.conf`

        ```
        network={
            ssid="WLAN_SSID"
            key_mgmt=WPA-PSK
            psk="WLAN_PASSWORD"
        }
        ```

### Create Release

Create the default release using mix template:

    ```
    $ mix distillery.init
    ```

Update the release configuration `rel/config.exs`:

 * Add a release configuration for grisp:

    ```
    environment :grisp do
        set include_erts: true
        set include_src: false
        set cookie: :"SOME_COOKIE"
    end
    ```

 * Set the default environment to `grisp`:

    ```
    use Distillery.Releases.Config,
        ...
        default_environment: :grisp
    ```


### Add Configuration

If not generated bu Mix template, add the file `config/config.exs`:

    ```
    use Mix.Config
    ```


### Check OTP Version

Verify that your default erlang version matches the one configured
(21 in the example).

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
