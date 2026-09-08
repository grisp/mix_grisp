defmodule Mix.Tasks.Grisp.Deploy do
  use Mix.Task

  @recursive true
  @shortdoc "Deploys a GRiSP release to a destination"

  @moduledoc """
  Deploys a GRiSP release to a directory or creates a release bundle.

      mix grisp.deploy [options] [-- MIX_RELEASE_OPTIONS]

  Options:

    * `--relname`, `-n` - release name
    * `--relvsn`, `-v` - release version
    * `--tar`, `-t` - create a bundle in `_grisp/deploy`
    * `--destination`, `-d` - copy destination
    * `--force`, `-f` - replace existing files
    * `--pre-script` - command to run before copying
    * `--post-script` - command to run after copying

  Arguments after `--` are passed to `mix release`.
  """

  @switches [
    relname: :string,
    relvsn: :string,
    tar: :boolean,
    destination: :string,
    force: :boolean,
    pre_script: :string,
    post_script: :string
  ]
  @aliases [n: :relname, v: :relvsn, t: :tar, d: :destination, f: :force]

  @impl Mix.Task
  def run(args) do
    {options, release_args} = MixGrisp.CLI.parse!(args, @switches, @aliases)
    MixGrisp.Deploy.run(options, release_args)
  end
end
