defmodule MixGrisp do
  @moduledoc false

  def ensure_started! do
    case Application.ensure_all_started(:grisp_tools) do
      {:ok, _} -> :ok
      {:error, reason} -> Mix.raise("Could not start grisp_tools: #{inspect(reason)}")
    end
  end

  def finalize(result), do: :grisp_tools.handlers_finalize(result)

  def header(message), do: Mix.shell().info(IO.ANSI.format([:blue, "===> ", message]))
  def info(message), do: Mix.shell().info(IO.iodata_to_binary(message))
  def warn(message), do: Mix.shell().info(IO.ANSI.format([:yellow, message]))

  def debug(term) do
    if Mix.debug?(), do: Mix.shell().info(IO.ANSI.format([:cyan, "mix_grisp: ", inspect(term)]))
    term
  end

  def relative(path) do
    path = to_string(path)
    cwd = File.cwd!()

    case Path.relative_to(path, cwd) do
      "../../../" <> _ -> path
      "../../" <> _ -> path
      relative -> relative
    end
  end
end
