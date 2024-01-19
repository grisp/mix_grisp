defmodule Mix.Tasks.Grisp.Deploy do
  @moduledoc """
  Deploys a GRiSP application.
  """
alias Mix.Project

  use Mix.Task
  @recursive true

  @shortdoc "Deploys a GRiSP application"

  def run(_args) do
    Mix.Task.run("compile", [])

    header("🐟 Deploying GRiSP application")

    {:ok, _} = Application.ensure_all_started(:grisp_tools)
    config = Mix.Project.config()[:grisp]
    IO.inspect(config)
    try do
      :grisp_tools.deploy(%{
        project_root: to_charlist(File.cwd!()),
        otp_version_requirement: to_charlist(config[:otp][:version] || "23"),
        platform: platform(config),
        apps: apps(),
        custom_build: false,
        copy: %{
          force: false,
          destination: to_charlist(config[:deploy][:destination] || "tmp/grisp_sd")
        },
        release: %{},
        handlers:
          :grisp_tools.handlers_init(%{
            event: {&event_handler/2, %{}},
            shell: {&shell_handler/3, nil},
            release: {&release_handler/2, nil}
          }),
        scripts: %{
          pre_script: config[:deploy][:pre_script] || :undefined,
          post_script: config[:deploy][:post_script] || :undefined
        }
      })
    catch
      :error, {:otp_version_mismatch, target, current} ->
        Mix.raise(
          "Current Erlang version (#{current}) does not match target" <>
            " Erlang version (#{target})"
        )
    end
  end

  defp event_handler(event, state) do
    debug(event, label: "event")
    {:ok, handle_event(event, state)}
  end

  defp handle_event({:otp_type, hash, :custom_build}, state) do
    header("Using custom OTP (#{short(hash)})")
    state
  end

  defp handle_event({:otp_type, hash, :package}, state) do
    header("Downloading OTP (#{short(hash)})")
    info("Version: #{short(hash)}")
    state
  end

  defp handle_event({:package, {:download_start, size}}, state) do
    IO.write("    0%")
    Map.put(state, :progress, {0, size})
  end

  defp handle_event(
         {:package, {:download_progress, current}},
         %{:progress => {tens, total}} = state
       ) do
    new_tens = round(current / total * 10)

    if new_tens > tens do
      IO.write(" #{new_tens * 10}%")
    end

    %{state | :progress => {new_tens, total}}
  end

  defp handle_event({:package, {:download_complete, _etag}}, state) do
    IO.write(" OK\n")
    state
  end

  defp handle_event({:package, :download_cached}, state) do
    info("Download already cached")
    state
  end

  defp handle_event({:package, {:http_error, other}}, state) do
    warn("Download error: #{inspect(other)}")
    info("Using cached file")
    state
  end

  defp handle_event({:package, {:extract, :up_to_date}}, state) do
    info("Current package up to date")
    state
  end

  defp handle_event({:package, {:extract, {:start, _package}}}, state) do
    info("Extracting package")
    state
  end

  defp handle_event({:package, {:extract_failed, reason}}, _State) do
    fail!("Tar extraction failed: #{inspect(reason)}")
  end

  defp handle_event({:release, {:start, _release}}, state) do
    header("Creating release")
    state
  end

  defp handle_event({:release, {:done, release}}, state) do
    info("Release complete: #{release.name}-#{release.version}")
    state
  end

  defp handle_event({:deployment, :init}, state) do
    header("Deploying")
    state
  end

  defp handle_event({:deployment, :script, name, {:run, _script}}, state) do
    info("Running #{name}")
    state
  end

  defp handle_event({:deployment, :script, _name, {:result, _output}}, state) do
    state
  end

  defp handle_event({:deployment, :release, {:copy, _source, _target}}, state) do
    info("Copying release...")
    state
  end

  defp handle_event({:deployment, {:files, {:init, _dest}}}, state) do
    info("Copying files...")
    state
  end

  defp handle_event({:deployment, :files, {:copy_error, {:exists, file}}}, _State) do
    fail!("Destination #{file} already exists (use --force to overwrite)")
  end

  defp handle_event({:deployment, :done}, state) do
    header(IO.ANSI.format(["Deployment ", :green, "succesful", :blue, "!"]))
    state
  end

  defp handle_event(_event, state) do
    state
  end

  defp shell_handler(raw_cmd, opts, state) do
    IO.inspect({raw_cmd, opts, state})
    cmd = raw_cmd |> IO.iodata_to_binary()
    debug(cmd, label: "cmd")

    [cmd | args] = String.split(cmd)
    args = for arg <- args, do: String.trim(arg, "\"")

    opts =
      Keyword.update!(opts, :env, fn env ->
        for {k, v} <- env, do: {List.to_string(k), List.to_string(v)}
      end)

    {result, 0} = System.cmd(cmd, args, opts)
    {{:ok, result}, state}
  end

  defp release_handler(%{erts: erts} = relspec, state) do
    debug(relspec, label: "relspec")
    name = :default
    env = :grisp

    {:ok, config} = Distillery.Releases.Config.get([
      selected_release: name,
      selected_environment: env,
      executable: [enabled: false, transient: false],
      is_upgrade: false,
      no_tar: true,
      upgrade_from: :latest
    ])
    # TODO: Limit release apps to only deps (doesn't work with Distillery?)
    config = config
      |> conf_profile_update(env, :include_erts, to_string(erts))
      # |> conf_release_update(name, :applications, []) # Remove distillery apps
    # IO.inspect(config, label: "release_config")
    Code.ensure_loaded(Mix.Grisp.ReleasePlugin)
    Distillery.Releases.Shell.configure(:quiet)
    release = case Distillery.Releases.Assembler.assemble(config) do
      {:ok, release} ->
        # IO.inspect(release, label: "release")
        release
      {:error, _} = err ->
        fail!(Distillery.Releases.Errors.format_error(err))
    end
    relspec = Map.merge(relspec, %{
      :dir => to_charlist(release.profile.output_dir),
      :name => to_charlist(release.name),
      :version => to_charlist(release.version)
    })
    {relspec, state}
  end

  defp conf_profile_update(config, env, key, value) do
    put_in(config, [
      Access.key!(:environments),
      env,
      Access.key!(:profile),
      Access.key!(key)
    ], value)
  end

  # defp conf_release_update(config, :default, key, value) do
  #   release_name = List.first(Map.keys(config.releases))
  #   put_in(config, [
  #     Access.key!(:releases),
  #     release_name,
  #     Access.key!(key)
  #   ], value)
  # end

  # gathering the apps and their deps to build the grisp overlay later
  @spec apps() :: [{Application.app(), %{dir: charlist(), deps: []}}]
  defp apps do
    old = Mix.env()
    Mix.env(:grisp)
    config = Mix.Project.config()
    app = {config[:app], %{dir: Mix.Project.app_path(), deps: Project.deps_apps()}}
    {_, %{name: bottom}} =  Mix.ProjectStack.top_and_bottom()
    {_, all_deps} = Mix.State.read_cache({:cached_deps, bottom})

    # IO.inspect(app)
    # IO.inspect(all_deps)

    all_apps =
      all_deps
      |> Enum.map(fn dep ->
        sub_deps = for d <- dep.deps do d.app end
        {dep.app, %{dir: dep.opts[:build], deps: sub_deps}}
      end)
    # IO.inspect(all_apps)
    Mix.env(old)
    apps = all_apps ++ [app]

    IO.inspect(apps)
    apps
  end

  defp platform(config) do
    case Keyword.get(config, :platform) do
      nil ->
        case Keyword.get(config, :board) do
          nil ->
            :grisp2

          board ->
            Mix.shell().warn("Configuration key 'board' is deprecated, use 'platform' instead.")
            board
        end

      platform ->
        platform
    end
  end

  defp short(string), do: String.slice(to_string(string), 0..8)

  defp header(message), do: Mix.shell().info(IO.ANSI.format([:blue, "===> ", message]))
  defp info(message), do: Mix.shell().info(message)
  defp warn(message), do: Mix.shell().info(IO.ANSI.format([:yellow, message]))
  defp fail!(message), do: Mix.shell().fail!(message)

  defp debug(message, label: label) when is_binary(message) do
    Mix.debug?() &&
      IO.ANSI.format([:cyan, "mix_grisp[#{label}]: ", message])
      |> IO.puts()
  end

  defp debug(term, opts) do
    debug(inspect(term), opts)
    term
  end
end
