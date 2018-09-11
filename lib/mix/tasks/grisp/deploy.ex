defmodule Mix.Tasks.Grisp.Deploy do
  @moduledoc """
  Documentation for MixGrisp.
  """

  @doc """
  Hello world.

  ## Examples

      iex> MixGrisp.hello()
      :world

  """

  use Mix.Task
  @recursive true

  # @preferred_cli_env :grisp

  @shortdoc "Deploys a GRiSP application"

  def run(_args) do
    Mix.raise "deploy!"
  end

end
