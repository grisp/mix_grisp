defmodule Mix.Tasks.Grisp.Firmware do
  use Mix.Task

  @shortdoc "Generates GRiSP firmware image files"
  @moduledoc """
  Generates system, eMMC image, and/or bootloader firmware.

      mix grisp.firmware [options] [-- MIX_RELEASE_OPTIONS]

  Use `--no-system`, `--image`, and `--bootloader` to select outputs. If
  `--bundle` is omitted, `mix grisp.deploy --tar` creates or reuses one.
  """

  @switches [
    relname: :string,
    relvsn: :string,
    bundle: :string,
    refresh: :boolean,
    force: :boolean,
    compress: :boolean,
    system: :boolean,
    image: :boolean,
    bootloader: :boolean,
    truncate: :boolean,
    quiet: :boolean
  ]
  @aliases [
    n: :relname,
    v: :relvsn,
    r: :refresh,
    f: :force,
    z: :compress,
    s: :system,
    i: :image,
    b: :bootloader,
    t: :truncate,
    q: :quiet
  ]

  @impl Mix.Task
  def run(args) do
    {options, release_args} = MixGrisp.CLI.parse!(args, @switches, @aliases)
    MixGrisp.Firmware.run(options, release_args)
  end
end
