defmodule Mix.Tasks.Grisp.Configure do
  use Mix.Task

  @shortdoc "Creates and configures a new GRiSP Mix application"
  @moduledoc """
  Creates a new Mix project configured for GRiSP.

      mix grisp.configure [options]

  Interactive mode is enabled by default. If the target directory exists,
  confirmation is required and existing files are preserved. Use
  `--no-interactive` for scripts.
  """

  @switches [
    interactive: :boolean,
    name: :string,
    otp_version: :string,
    jit: :string,
    dest: :string,
    desc: :string,
    copyright_year: :string,
    author_name: :string,
    author_email: :string,
    wifi: :boolean,
    ssid: :string,
    psk: :string,
    grisp_io: :boolean,
    grisp_io_linking: :string,
    epmd: :boolean,
    cookie: :string
  ]

  @aliases [
    i: :interactive,
    o: :otp_version,
    d: :dest,
    w: :wifi,
    g: :grisp_io,
    l: :grisp_io_linking,
    e: :epmd,
    c: :cookie
  ]

  @impl Mix.Task
  def run(args) do
    {options, []} = MixGrisp.CLI.parse!(args, @switches, @aliases)
    options = parse_jit(options)
    result = MixGrisp.Configure.run(options)
    Enum.each(result.created, &Mix.shell().info("Created #{&1}"))
    Mix.shell().info("Configured GRiSP Mix project #{result.name}")
  end

  defp parse_jit(options) do
    case Keyword.fetch(options, :jit) do
      {:ok, "true"} ->
        Keyword.put(options, :jit, true)

      {:ok, "false"} ->
        Keyword.put(options, :jit, false)

      {:ok, value} ->
        Mix.raise("Invalid value for --jit: #{inspect(value)} (expected true or false)")

      :error ->
        options
    end
  end
end
