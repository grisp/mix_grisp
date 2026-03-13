# GRiSP Mix plug-in

Mix plug-in to scaffold and deploy GRiSP applications for the [GRiSP board][grisp].

## Summary

Add `mix_grisp` to your project dependencies:

```elixir
def deps do
  [
    {:mix_grisp, "~> 0.2.0", only: :dev}
  ]
end
```

The plugin currently provides:

- `mix grisp.configure`
- `mix grisp.deploy`

Implementation notes:

- [CLI Flow](docs/cli_flow.md)

## Recommended Flow

The best approach today is:

1. Start from a simple `mix new` project.
2. Add `mix_grisp` to `deps/0`.
3. Run `mix deps.get`.
4. Run `mix grisp.configure` before heavily customizing `mix.exs` or `config/config.exs`.
5. Review any printed manual steps after the command finishes.

`mix grisp.configure` is intentionally conservative:

- it creates missing GRiSP files
- it patches simple `mix new`-style `mix.exs` files automatically
- it patches `config/config.exs` for GRiSP.io when possible
- if the file shape is not safe to rewrite, it prints exact manual steps instead

## Configure

Run the interactive flow:

```sh
mix grisp.configure
```

Or run it non-interactively with flags:

```sh
mix grisp.configure --interactive false --name demo --network true --network-type wifi
```

### Important Flags

- `--interactive true|false`
- `--name <otp_app>`
- `--otp-version <version>`
- `--network true|false`
- `--network-type ethernet|wifi`
- `--ssid <ssid>`
- `--psk <psk>`
- `--grisp-io true|false`
- `--grisp-io-linking true|false`
- `--token <linking_token>`
- `--epmd true|false`
- `--node-name <short_name>`
- `--cookie <cookie>`

### What It Generates

Depending on the selected options, `mix grisp.configure` creates:

- `config/config.exs` if it does not already exist
- `grisp/grisp2/common/deploy/files/grisp.ini.mustache`
- `grisp/grisp2/common/deploy/files/wpa_supplicant.conf` for Wi-Fi
- `grisp/grisp2/common/deploy/files/erl_inetrc` when GRiSP.io is not enabled

The base `grisp.ini.mustache` is kept canonical and then refined during rendering:

- Wi-Fi adds `wpa=wpa_supplicant.conf`
- `epmd` adds:
  - `-kernel inetrc "./erl_inetrc"`
  - `-internal_epmd epmd_sup`
  - `-sname <node_name>`
  - `-setcookie <cookie>`

### What It Patches Automatically

For simple `mix new`-style projects, the plugin can patch `mix.exs` to add:

- `grisp: grisp()`
- `releases: releases()`
- `{:grisp, "~> 2.4"}`
- `{:epmd, git: "https://github.com/erlang/epmd", ref: "4d1a59", runtime: false}` when `epmd` is enabled
- `def grisp do`
- `def releases do`
- `included_applications: [:epmd]` in `application/0` when `epmd` is enabled

For GRiSP.io, the plugin can patch `config/config.exs` to add:

- `:grisp_keychain`
- `:grisp_cryptoauth`
- `:grisp_connect`
- `:grisp_updater`

If linking is enabled, the linking token is added to `config :grisp_connect`.

### What Still Requires Review

The plugin may still print manual steps. This is expected when:

- `mix.exs` does not match a simple patchable shape
- GRiSP.io dependencies need to be added with versions that match your GRiSP stack
- additional app/runtime choices need review

In particular, GRiSP.io dependency versions are not auto-selected by the plugin.
You should choose versions that match your target GRiSP setup.

## Example Commands

Wi-Fi project:

```sh
mix grisp.configure \
  --interactive false \
  --name demo \
  --network true \
  --network-type wifi \
  --ssid mywifi \
  --psk supersecret
```

Ethernet + Erlang distribution:

```sh
mix grisp.configure \
  --interactive false \
  --name demo \
  --network true \
  --network-type ethernet \
  --epmd true \
  --node-name mynode \
  --cookie mycookie
```

GRiSP.io with device linking:

```sh
mix grisp.configure \
  --interactive false \
  --name demo \
  --network true \
  --network-type wifi \
  --grisp-io true \
  --grisp-io-linking true \
  --token link-token
```

## Deploy

After configuration and dependency setup, deploy with:

```sh
mix grisp.deploy
```

## Notes

- Use the same OTP version locally that you target in the generated GRiSP configuration.
- If you compiled dependencies with the wrong OTP version, remove `_build` and `deps`, run `mix deps.get`, and build again.
- Read the GRiSP networking chapter in the wiki for board-specific runtime details.

[grisp]: https://www.grisp.org
