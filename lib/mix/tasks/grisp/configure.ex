defmodule Mix.Tasks.Grisp.Configure do
  use Mix.Task

  @shortdoc "Creates and configures a new GRiSP Mix application"
  @moduledoc """
  Creates a new Mix project configured for GRiSP.

      mix grisp.configure [options]

  Interactive mode is enabled by default. Use `--no-interactive` for scripts.
  """

  @switches [
    interactive: :boolean,
    name: :string,
    otp_version: :string,
    jit: :boolean,
    dest: :string,
    desc: :string,
    copyright_year: :string,
    author_name: :string,
    author_email: :string,
    network: :boolean,
    wifi: :boolean,
    ssid: :string,
    psk: :string,
    grisp_io: :boolean,
    grisp_io_linking: :boolean,
    token: :string,
    epmd: :boolean,
    cookie: :string
  ]

  @aliases [
    i: :interactive,
    o: :otp_version,
    j: :jit,
    d: :dest,
    n: :network,
    w: :wifi,
    g: :grisp_io,
    l: :grisp_io_linking,
    t: :token,
    e: :epmd,
    c: :cookie
  ]

  @impl Mix.Task
  def run(args) do
    {options, []} = MixGrisp.CLI.parse!(args, @switches, @aliases)
    result = MixGrisp.Configure.run(options)
    Enum.each(result.created, &Mix.shell().info("Created #{&1}"))
    Mix.shell().info("Configured GRiSP Mix project #{result.name}")
  end
end
