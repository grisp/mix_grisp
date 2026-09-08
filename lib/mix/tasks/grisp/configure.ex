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

  @boolean_flags %{
    "--interactive" => "--interactive",
    "-i" => "--interactive",
    "--jit" => "--jit",
    "-j" => "--jit",
    "--network" => "--network",
    "-n" => "--network",
    "--wifi" => "--wifi",
    "-w" => "--wifi",
    "--grisp-io" => "--grisp-io",
    "-g" => "--grisp-io",
    "--grisp-io-linking" => "--grisp-io-linking",
    "-l" => "--grisp-io-linking",
    "--epmd" => "--epmd",
    "-e" => "--epmd"
  }

  @impl Mix.Task
  def run(args) do
    args = normalize_boolean_args(args)
    {options, []} = MixGrisp.CLI.parse!(args, @switches, @aliases)
    result = MixGrisp.Configure.run(options)
    Enum.each(result.created, &Mix.shell().info("Created #{&1}"))
    Mix.shell().info("Configured GRiSP Mix project #{result.name}")
  end

  defp normalize_boolean_args([flag, value | rest]) when is_map_key(@boolean_flags, flag) do
    normalized = Map.fetch!(@boolean_flags, flag)

    case value do
      "true" ->
        [normalized | normalize_boolean_args(rest)]

      "false" ->
        ["--no-" <> String.trim_leading(normalized, "--") | normalize_boolean_args(rest)]

      value when is_binary(value) ->
        if String.starts_with?(value, "-") do
          [normalized | normalize_boolean_args([value | rest])]
        else
          Mix.raise("Invalid boolean value: #{inspect(value)}")
        end
    end
  end

  defp normalize_boolean_args([argument | rest]),
    do: [argument | normalize_boolean_args(rest)]

  defp normalize_boolean_args([]), do: []
end
