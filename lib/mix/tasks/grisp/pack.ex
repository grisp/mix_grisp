defmodule Mix.Tasks.Grisp.Pack do
  use Mix.Task

  @shortdoc "Generates a GRiSP software update package"
  @moduledoc """
  Generates a signed or unsigned software update package.

      mix grisp.pack [options] [-- MIX_RELEASE_OPTIONS]

  Firmware is generated automatically unless `--system` is supplied. With an
  explicit bootloader, both `--system` and `--bootloader` are required.
  """

  @switches [
    relname: :string,
    relvsn: :string,
    system: :string,
    bootloader: :string,
    block_size: :integer,
    key: :string,
    with_bootloader: :boolean,
    refresh: :boolean,
    force: :boolean,
    quiet: :boolean
  ]
  @aliases [
    n: :relname,
    v: :relvsn,
    k: :key,
    b: :with_bootloader,
    r: :refresh,
    f: :force,
    q: :quiet
  ]

  @impl Mix.Task
  def run(args) do
    {options, release_args} = MixGrisp.CLI.parse!(args, @switches, @aliases)
    MixGrisp.Pack.run(options, release_args)
  end
end
