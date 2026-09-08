defmodule Mix.Tasks.Grisp.Package do
  use Mix.Task

  @shortdoc "Lists pre-built GRiSP packages"
  @moduledoc """
  Lists available packages.

      mix grisp.package list [--platform grisp2] [--type otp|toolchain]
                             [--columns version,hash] [--cached]
  """

  @switches [platform: :string, columns: :string, type: :string, cached: :boolean]
  @aliases [p: :platform, c: :columns, t: :type]
  @columns %{
    otp: [:version, :hash, :name, :size, :etag, :url, :last_modified],
    toolchain: [:os, :os_version, :revision, :latest, :name, :size, :etag, :url, :last_modified]
  }

  @impl Mix.Task
  def run(["list" | args]) do
    {options, []} = MixGrisp.CLI.parse!(args, @switches, @aliases)
    MixGrisp.ensure_started!()

    type = parse_type(options[:type] || "otp")
    platform = String.to_atom(options[:platform] || to_string(MixGrisp.Config.platform()))
    source = if options[:cached], do: :cache, else: :online
    columns = parse_columns(type, options[:columns])

    title =
      if type == :otp,
        do: "GRiSP pre-built OTP versions for '#{platform}'",
        else: "GRiSP toolchain packages"

    MixGrisp.info(title)

    %{type: type, platform: platform, source: source}
    |> :grisp_tools.list_packages()
    |> render(columns)
  rescue
    error in Mix.Error -> reraise(error, __STACKTRACE__)
  catch
    :error, reason -> Mix.raise(package_error(reason))
  end

  def run([]), do: Mix.raise("Expected a package command. Usage: mix grisp.package list")
  def run([command | _]), do: Mix.raise("Unknown package command: #{command}")

  defp parse_type("otp"), do: :otp
  defp parse_type("toolchain"), do: :toolchain
  defp parse_type(type), do: Mix.raise("Unknown package type: #{type}")

  defp parse_columns(type, nil) do
    if type == :otp, do: [:version], else: [:os, :latest, :os_version, :url]
  end

  defp parse_columns(type, value) do
    columns = value |> String.split(",", trim: true) |> Enum.map(&String.to_atom/1)
    invalid = columns -- Map.fetch!(@columns, type)

    cond do
      columns == [] -> Mix.raise("No columns specified")
      invalid != [] -> Mix.raise("Unknown columns: #{Enum.join(invalid, ", ")}")
      true -> columns
    end
  end

  defp render([], _columns), do: MixGrisp.warn("No packages found")

  defp render(items, columns) do
    rows =
      items
      |> Enum.sort_by(fn item -> Enum.map(columns, &sort_value(&1, Map.get(item, &1))) end)
      |> Enum.map(fn item -> Enum.map(columns, &format_value(&1, Map.get(item, &1))) end)

    headers = Enum.map(columns, &title/1)
    widths = column_widths([headers | rows])
    print_row(headers, widths)
    print_row(Enum.map(widths, &String.duplicate("-", &1)), widths)
    Enum.each(rows, &print_row(&1, widths))
  end

  defp column_widths(rows) do
    rows
    |> Enum.zip_with(fn values -> values |> Enum.map(&String.length/1) |> Enum.max() end)
  end

  defp print_row(values, widths) do
    values
    |> Enum.zip(widths)
    |> Enum.map_join("  ", fn {value, width} -> String.pad_trailing(value, width) end)
    |> MixGrisp.info()
  end

  defp title(column),
    do: column |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()

  defp sort_value(column, value) when column in [:version, :os_version], do: version_key(value)
  defp sort_value(_column, value), do: to_string(value || "")

  defp version_key(value) do
    value
    |> to_string()
    |> String.split(~r/[^0-9]+/, trim: true)
    |> Enum.map(&String.to_integer/1)
  end

  defp format_value(:size, value) when is_number(value),
    do: format_size(value * 1.0, ["B", "KiB", "MiB", "GiB", "TiB"])

  defp format_value(:latest, true), do: "true"
  defp format_value(:latest, _), do: ""

  defp format_value(:last_modified, value) when is_integer(value),
    do: value |> DateTime.from_unix!() |> DateTime.to_iso8601()

  defp format_value(_column, nil), do: ""
  defp format_value(_column, value), do: to_string(value)

  defp format_size(size, [_unit | rest]) when size > 1000 and rest != [],
    do: format_size(size / 1024, rest)

  defp format_size(size, [unit | _]),
    do: "#{Float.round(size, if(size == trunc(size), do: 0, else: 1))} #{unit}"

  defp package_error({:not_implemented, type, source}),
    do: "Listing #{source} #{type} packages is not supported"

  defp package_error(error), do: "Could not list packages: #{inspect(error)}"
end
