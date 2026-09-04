defmodule Mix.Tasks.Grisp.Version do
  use Mix.Task

  @shortdoc "Prints mix_grisp and dependency versions"

  @impl Mix.Task
  def run([]) do
    {:ok, _} = Application.ensure_all_started(:mix_grisp)
    MixGrisp.ensure_started!()

    [:mix_grisp, :grisp_tools | applications(:mix_grisp) ++ applications(:grisp_tools)]
    |> Enum.uniq()
    |> Enum.reject(&(&1 in [:kernel, :stdlib]))
    |> Enum.each(fn app ->
      version = Application.spec(app, :vsn) || "unknown"
      path = app |> :code.lib_dir() |> to_string()
      Mix.shell().info("#{app}: #{version} (#{path})")
    end)
  end

  def run(args), do: Mix.raise("Unexpected arguments: #{Enum.join(args, " ")}")

  defp applications(app), do: Application.spec(app, :applications) || []
end
