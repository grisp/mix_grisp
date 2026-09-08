defmodule MixGrisp.CLI do
  @moduledoc false

  def parse!(args, switches, aliases \\ []) do
    {own, extra} = split_extra(args)

    case OptionParser.parse(own, strict: switches, aliases: aliases) do
      {options, [], []} -> {options, extra}
      {_options, rest, []} -> Mix.raise("Unexpected arguments: #{Enum.join(rest, " ")}")
      {_options, _rest, invalid} -> Mix.raise("Invalid options: #{format_invalid(invalid)}")
    end
  end

  defp split_extra(args) do
    case Enum.split_while(args, &(&1 != "--")) do
      {own, ["--" | extra]} -> {own, extra}
      {own, []} -> {own, []}
    end
  end

  defp format_invalid(invalid) do
    Enum.map_join(invalid, ", ", fn
      {option, nil} -> option
      {option, value} -> "#{option}=#{value}"
    end)
  end
end
