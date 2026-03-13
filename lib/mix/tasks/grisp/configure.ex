defmodule Mix.Tasks.Grisp.Configure do
  @moduledoc """
  Scaffolds GRiSP configuration files for a Mix project.
  """

  use Mix.Task

  alias MixGrisp.Configure

  @shortdoc "Scaffolds GRiSP configuration files"

  @switches [
    interactive: :string,
    name: :string,
    otp_version: :string,
    destination: :string,
    network: :string,
    network_type: :string,
    ssid: :string,
    psk: :string,
    grisp_io: :string,
    grisp_io_linking: :string,
    token: :string,
    epmd: :string,
    node_name: :string,
    cookie: :string
  ]

  def run(args) do
    {opts, _argv, invalid} = OptionParser.parse(args, strict: @switches)
    # For now CLI errors bubble up as Mix exceptions from the workflow layers.
    # If interactive mode grows, this task may need a friendlier error boundary.
    fail_on_invalid!(invalid)

    %{result: result, patch_result: patch_result} = Configure.run(opts)

    Enum.each(Enum.reverse(result.created), fn path ->
      Mix.shell().info("Created #{path}")
    end)

    Enum.each(Enum.reverse(result.skipped), fn path ->
      Mix.shell().info("Skipped #{path}")
    end)

    print_patch_result(patch_result)
  end

  defp fail_on_invalid!([]), do: :ok

  defp fail_on_invalid!(invalid) do
    formatted =
      invalid
      |> Enum.map_join(", ", &format_invalid_option/1)

    Mix.raise("Invalid options: #{formatted}")
  end

  defp format_invalid_option({<<"--", option::binary>>, value}), do: format_invalid_option({option, value})
  defp format_invalid_option({option, nil}), do: "--#{option}"
  defp format_invalid_option({option, value}), do: "--#{option}=#{value}"

  defp print_patch_result(%{status: :updated, updated: paths, manual: manual}) do
    Enum.each(paths, fn path ->
      Mix.shell().info("Updated #{path}")
    end)

    Enum.each(manual, fn step ->
      Mix.shell().info("Manual step:\n#{step}")
    end)
  end

  defp print_patch_result(%{status: :unchanged, manual: manual}) do
    Enum.each(manual, fn step ->
      Mix.shell().info("Manual step:\n#{step}")
    end)
  end

  defp print_patch_result(%{status: :manual, manual: manual}) do
    Mix.shell().info("Could not safely update mix.exs automatically.")

    Enum.each(manual, fn step ->
      Mix.shell().info("Manual step:\n#{step}")
    end)
  end
end
