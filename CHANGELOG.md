# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-09-08

### Added

- Port the `rebar3_grisp` workflow to Mix with tasks for building custom OTP
  systems, deploying releases, generating firmware, creating software update
  packages, listing pre-built packages, and collecting bug reports.
- Add `mix grisp.configure` to create GRiSP-ready Elixir projects, including
  release, Ethernet, optional Wi-Fi, distributed Erlang, and GRiSP.io
  configuration. Existing project files are preserved in interactive mode.
- Add release selection, archive deployment, custom destinations, pre- and
  post-deployment scripts, and forwarding of options to `mix release`.
- Add support for local and Docker GRiSP toolchains, custom OTP builds, and
  pre-built OTP package selection.

## [0.2.0] - 2024-03-21

### Added

- Support for GRiSP 2 board deployment with grisp_tools 2.x [#7](https://github.com/grisp/mix_grisp/pull/7)

### Changed

- Move to Elixir 1.16 and OTP 26 as suggested runtime versions
- New Changelog format

## [0.1.4] - 2019-12-01

### Changed

- Bump the version  [\#3](https://github.com/grisp/mix_grisp/pull/3) ([Theuns-Botha](https://github.com/Theuns-Botha))

### Fixed

- We need a new version [\#2](https://github.com/grisp/mix_grisp/issues/2)

## [0.1.3] - 2019-10-17

### Fixed

- Fix deploy for last Elixir versions and update README [\#1](https://github.com/grisp/mix_grisp/pull/1) ([sylane](https://github.com/sylane))


[unreleased]: https://github.com/grisp/mix_grisp/compare/1.0.0...HEAD
[1.0.0]: https://github.com/grisp/mix_grisp/compare/0.2.0...1.0.0
[0.2.0]: https://github.com/grisp/mix_grisp/compare/0.1.4...0.2.0
[0.1.4]: https://github.com/grisp/mix_grisp/compare/0.1.3...0.1.4
[0.1.3]: https://github.com/grisp/mix_grisp/compare/b50583ccac82282bb522a67a0fcf1bad8023139e...0.1.3
