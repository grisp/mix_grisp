defmodule Mix.Tasks.Grisp.Build do
  use Mix.Task

  @shortdoc "Builds a custom Erlang/OTP system for GRiSP"
  @moduledoc """
  Builds the custom Erlang/OTP system configured under `grisp: [build: ...]`.

      mix grisp.build [--clean] [--no-configure] [--tar] [--update-prebuild]
  """

  @switches [clean: :boolean, configure: :boolean, tar: :boolean, update_prebuild: :boolean]
  @aliases [c: :clean, g: :configure, t: :tar, p: :update_prebuild]

  @impl Mix.Task
  def run(args) do
    {options, []} = MixGrisp.CLI.parse!(args, @switches, @aliases)
    MixGrisp.ensure_started!()

    unless MixGrisp.Config.custom_build?() do
      Mix.raise("There is no :build section in the :grisp configuration")
    end

    toolchain = toolchain!()

    spec = %{
      project_root: to_charlist(MixGrisp.Project.root()),
      apps: MixGrisp.Project.apps(),
      otp_version_requirement: to_charlist(MixGrisp.Config.otp_version()),
      jit: MixGrisp.Config.otp_jit(),
      platform: MixGrisp.Config.platform(),
      custom_build: true,
      build: %{
        flags: %{
          clean: Keyword.get(options, :clean, false),
          configure: Keyword.get(options, :configure, true),
          tar: Keyword.get(options, :tar, false),
          update_prebuild: Keyword.get(options, :update_prebuild, false)
        }
      },
      paths: %{toolchain: toolchain},
      handlers: MixGrisp.Handler.handlers(&event/2)
    }

    spec |> :grisp_tools.build() |> MixGrisp.finalize()
    MixGrisp.info("Done")
  rescue
    error in Mix.Error -> reraise(error, __STACKTRACE__)
  catch
    :error, reason -> Mix.raise(build_error(reason))
  end

  def event(event, state) do
    case event do
      [:build] ->
        MixGrisp.header("Building OTP for GRiSP")

      [:build, {:platform, platform}] ->
        MixGrisp.info("* Platform: #{platform}")

      [:build, :validate, :apps, {:grisp_dir_without_dep, app}] ->
        MixGrisp.warn(
          "Application #{app} has a grisp directory but does not depend on :grisp; its build files are ignored"
        )

      [:build, :validate, :version] ->
        MixGrisp.info("* Resolving OTP version")

      [:build, :validate, :version, {:selected, version, target}] ->
        MixGrisp.info("    #{version} (requirement was #{inspect(to_string(target))})")

      [:build, :download] ->
        MixGrisp.info("* Downloading")

      [:build, :download, :_skip] ->
        MixGrisp.info("    (skipped, using existing download)")

      [:build, :repo, :check, {:error, error}] ->
        MixGrisp.warn("Repository integrity check failed: #{inspect(error)}")

      [:build, :prepare] ->
        MixGrisp.info("Preparing")

      [:build, :prepare, :clean, :_run] ->
        MixGrisp.info("* Cleaning...")

      [:build, :prepare, :patch] ->
        MixGrisp.info("* Patching")

      [:build, :prepare, :patch, {action, %{app: app, name: file}}] ->
        suffix = if action == :skip, do: " (already applied, skipping)", else: ""
        MixGrisp.info("    [#{app}] #{file}#{suffix}")

      [:build, :prepare, :copy, type] ->
        MixGrisp.info("* Copying #{type}")

      [:build, :prepare, :copy, _type, :_skip] ->
        MixGrisp.info("    (none found)")

      [:build, :prepare, :copy, _type, %{app: app, name: file}] ->
        MixGrisp.info("    [#{app}] #{file}")

      [:build, :compile] ->
        MixGrisp.info("Compiling")

      [:build, :compile, :configure] ->
        MixGrisp.info("* Configuring")

      [:build, :compile, :configure, {:_override, reason}] ->
        MixGrisp.info("    (forced by #{reason})")

      [:build, :compile, :configure, :_skip] ->
        MixGrisp.info("    (skipped)")

      [:build, :compile, :boot] ->
        MixGrisp.info("* Compiling (this may take a while)")

      [:build, :compile, :install] ->
        MixGrisp.info("* Installing")

      [:build, :compile, :install, :hook, :post_install, {:run, %{app: app, name: name}}] ->
        MixGrisp.info("    [#{app}] #{name}")

      [:build, :tar, {:file, file}] ->
        MixGrisp.info("* Packaging\n    #{file}")

      _ ->
        MixGrisp.debug(event)
    end

    {:ok, state}
  end

  defp toolchain! do
    case MixGrisp.Config.toolchain() do
      {:directory, _} = toolchain -> toolchain
      {:docker, _} = toolchain -> toolchain
      {:error, :docker_not_found} -> Mix.raise("Docker is not available")
      nil -> Mix.raise("Configure grisp[:build][:toolchain] or set GRISP_TOOLCHAIN")
    end
  end

  defp build_error({:missing_toolchain_revision, source}),
    do: "Could not determine toolchain revision (missing file: #{source})"

  defp build_error({:toolchain_root_invalid, directory}),
    do: "The toolchain directory is invalid: #{inspect(directory)}"

  defp build_error({:otp_version_not_found, configured}),
    do: "Could not find an OTP version matching #{inspect(configured)}"

  defp build_error(error), do: "Unexpected build error: #{inspect(error)}"
end
