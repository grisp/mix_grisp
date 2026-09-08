defmodule Mix.Tasks.Grisp.Report do
  use Mix.Task

  @shortdoc "Gathers a GRiSP project bug report"
  @moduledoc "Run `mix grisp.report`, optionally with `--tar`."

  @impl Mix.Task
  def run(args) do
    {options, []} = MixGrisp.CLI.parse!(args, [tar: :boolean], t: :tar)
    MixGrisp.ensure_started!()
    report_dir = MixGrisp.Project.report_dir()

    %{
      project_root: to_charlist(MixGrisp.Project.root()),
      report_dir: to_charlist(report_dir),
      flags: %{tar: Keyword.get(options, :tar, false)},
      apps: MixGrisp.Project.apps(),
      otp_version_requirement: to_charlist(MixGrisp.Config.otp_version()),
      jit: MixGrisp.Config.otp_jit(),
      custom_build: MixGrisp.Config.custom_build?(),
      platform: MixGrisp.Config.platform(),
      handlers: MixGrisp.Handler.handlers(&event/2)
    }
    |> :grisp_tools.report()
    |> MixGrisp.finalize()

    MixGrisp.info("----------------------")

    MixGrisp.info(
      "Please check that #{report_dir} contains no private information before sharing it."
    )

    MixGrisp.info("Done")
  rescue
    error in Mix.Error -> reraise(error, __STACKTRACE__)
    error -> Mix.raise("Unexpected report error: #{inspect(error)}")
  end

  def event(event, state) do
    case event do
      [:report] ->
        MixGrisp.info("Grisp report\n======================")

      [:report, :write_report, :skip] ->
        MixGrisp.info("Report directory is already present.")

      [:report, :write_report, {:new_report, path}] ->
        MixGrisp.info("New report written at #{path}.")

      [:report, _, :files, {:copy, file}] ->
        MixGrisp.info("Copied -> #{file}")

      [:report, _, :files, {:missing, file}] ->
        MixGrisp.info("Missing -> #{file}")

      [:report, _, :write, file] ->
        MixGrisp.info("Written -> #{file}")

      [:report, :tar, file] ->
        MixGrisp.info("Created tarball -> #{file}")

      _ ->
        MixGrisp.debug(event)
    end

    {:ok, state}
  end
end
