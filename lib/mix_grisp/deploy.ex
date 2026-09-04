defmodule MixGrisp.Deploy do
  @moduledoc false

  alias MixGrisp.{Config, Handler, Project}

  def run(options, release_args \\ []) do
    MixGrisp.ensure_started!()
    compile_for_grisp()

    {name, version} = Project.select_release(options[:relname], options[:relvsn])
    tar? = Keyword.get(options, :tar, false)
    destination = Config.deploy(:destination, options)
    force? = Keyword.get(options, :force, false)

    distribute =
      distribution_spec(tar?, %{
        destination: destination,
        bundle: Project.bundle_file(name, version),
        force: force?,
        pre_script: normalize_script(Config.deploy(:pre_script, options)),
        post_script: normalize_script(Config.deploy(:post_script, options))
      })

    handlers =
      Handler.handlers(&event/2, %{name: name, version: version}, %{
        release: {&release/2, %{name: name, args: release_args}}
      })

    %{
      project_root: to_charlist(Project.root()),
      otp_version_requirement: to_charlist(Config.otp_version()),
      jit: Config.otp_jit(),
      platform: Config.platform(),
      apps: Project.apps(),
      custom_build: Config.custom_build?(),
      distribute: distribute,
      release: %{name: name, version: to_charlist(version), profiles: Project.profiles()},
      handlers: handlers
    }
    |> :grisp_tools.deploy()
    |> MixGrisp.finalize()

    MixGrisp.info("Deployment done")
    %{name: name, version: version, bundle: Project.bundle_file(name, version)}
  rescue
    error in Mix.Error -> reraise(error, __STACKTRACE__)
    error -> Mix.raise(format_error(error))
  end

  def event(event, state) do
    MixGrisp.debug(event)
    {:ok, handle_event(event, state)}
  end

  def release(relspec, %{name: name, args: args} = state) do
    MixGrisp.debug({:release, relspec})
    Process.put(:relspec, relspec)

    try do
      Mix.Task.reenable("release")
      Mix.Task.run("release", [to_string(name) | args])
      spec = Process.get(:spec) || Mix.raise("mix release did not initialize MixGrisp.Release")

      {%{
         dir: to_charlist(spec.path),
         name: spec.name,
         version: to_charlist(spec.version)
       }, state}
    after
      Process.delete(:relspec)
      Process.delete(:spec)
    end
  end

  defp compile_for_grisp do
    old_grisp = System.get_env("GRISP")
    old_platform = System.get_env("GRISP_PLATFORM")

    try do
      System.put_env("GRISP", "yes")
      System.put_env("GRISP_PLATFORM", to_string(Config.platform()))
      Mix.Task.reenable("compile")
      Mix.Task.run("compile", [])
    after
      restore_env("GRISP", old_grisp)
      restore_env("GRISP_PLATFORM", old_platform)
    end
  end

  defp distribution_spec(true, %{bundle: bundle, force: force?}) do
    [
      {:bundle,
       %{
         type: :archive,
         force: force?,
         compressed: true,
         destination: to_charlist(bundle)
       }}
    ]
  end

  defp distribution_spec(false, %{destination: nil}) do
    Mix.raise("""
    No deploy destination specified.
    Pass --tar, pass --destination PATH, or configure:

        grisp: [deploy: [destination: "/tmp/grisp"]]
    """)
  end

  defp distribution_spec(false, options) do
    [
      {:copy,
       %{
         type: :copy,
         force: options.force,
         destination: to_charlist(options.destination),
         scripts: %{
           pre_script: options.pre_script,
           post_script: options.post_script
         }
       }}
    ]
  end

  defp handle_event([:deploy, :validate, :version], state) do
    MixGrisp.info("* Resolving OTP version")
    state
  end

  defp handle_event([:deploy, :validate, :version, {:selected, version, target}], state) do
    MixGrisp.info("    #{version} (requirement was #{inspect(to_string(target))})")
    state
  end

  defp handle_event([:deploy, :validate, :version, {:mismatch, target, current}], _state) do
    Mix.raise(
      "Current Erlang version (#{inspect(current)}) does not match target (#{inspect(target)})"
    )
  end

  defp handle_event([:deploy, :validate, :version, {:connection_error, error}], state) do
    MixGrisp.warn("Could not list packages (#{inspect(error)}); using cache")
    state
  end

  defp handle_event([:deploy, :package, {:type, {type, hash}}], state)
       when type in [:custom_build, :package] do
    source = if type == :custom_build, do: "custom OTP", else: "pre-built OTP package"
    MixGrisp.info("* Using #{source} (#{short(hash)})")
    state
  end

  defp handle_event([:deploy, :package, :download, {:start, size}], state) do
    IO.write("* Downloading package\n    0%")
    Map.put(state, :progress, {0, size})
  end

  defp handle_event(
         [:deploy, :package, :download, {:progress, current}],
         %{progress: {tens, total}} = state
       )
       when is_integer(total) and total > 0 do
    new_tens = round(current / total * 10)
    if new_tens > tens, do: IO.write(" #{new_tens * 10}%")
    %{state | progress: {new_tens, total}}
  end

  defp handle_event([:deploy, :package, :download, {:complete, _etag}], state) do
    IO.write(" OK\n")
    state
  end

  defp handle_event([:deploy, :package, :download, :_skip], state) do
    MixGrisp.info("    (file cached)")
    state
  end

  defp handle_event([:deploy, :package, :download, {:error, reason}], state) do
    MixGrisp.warn("Download error: #{inspect(reason)}\n    (using cached file)")
    state
  end

  defp handle_event([:deploy, :package, :extract], state) do
    MixGrisp.info("* Extracting package")
    state
  end

  defp handle_event([:deploy, :package, :extract, :_skip], state) do
    MixGrisp.info("    (already extracted)")
    state
  end

  defp handle_event([:deploy, :package, :extract, {:error, reason}], _state) do
    Mix.raise("Extraction failed: #{inspect(reason)}")
  end

  defp handle_event([:deploy, :distribute, name, script, {:run, _command}], state) do
    MixGrisp.info("* Running #{name} #{script}")
    state
  end

  defp handle_event([:deploy, :distribute, _name, _script, {:result, output}], state) do
    if String.trim(to_string(output)) != "", do: MixGrisp.info(String.trim(to_string(output)))
    state
  end

  defp handle_event([:deploy, :distribute, :bundle, :release, {:archive, _, _}], state) do
    MixGrisp.info("* Bundling release...")
    state
  end

  defp handle_event([:deploy, :distribute, :copy, :release, {:copy, _, _}], state) do
    MixGrisp.info("* Copying release...")
    state
  end

  defp handle_event([:deploy, :distribute, name, :files, {:init, _}], state) do
    MixGrisp.info("* #{if name == :bundle, do: "Bundling", else: "Copying"} files...")
    state
  end

  defp handle_event([:deploy, :distribute, _name, :files, {_, %{app: app, target: file}}], state) do
    MixGrisp.info("    [#{app}] #{file}")
    state
  end

  defp handle_event([:deploy, :distribute, :bundle, :archive, {:closed, path}], state) do
    MixGrisp.info("* GRiSP deploy bundle archived in #{MixGrisp.relative(path)}")
    state
  end

  defp handle_event([:deploy, :distribute, _name, :files, {:error, :file_exists, path}], _state),
    do:
      Mix.raise(
        "Destination #{MixGrisp.relative(path)} already exists (use --force to overwrite)"
      )

  defp handle_event([:deploy, :distribute, _name, {:error, reason, path}], _state) do
    Mix.raise("Deployment destination error for #{MixGrisp.relative(path)}: #{reason}")
  end

  defp handle_event(event, state) do
    case List.last(event) do
      {:error, reason, path} ->
        Mix.raise("Deploy error #{inspect(reason)}: #{MixGrisp.relative(path)}")

      {:error, reason} ->
        Mix.raise("Deploy error: #{inspect(reason)}")

      _ ->
        state
    end
  end

  defp normalize_script(nil), do: :undefined
  defp normalize_script(script), do: to_charlist(script)

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
  defp short(value), do: value |> to_string() |> String.slice(0, 9)

  defp format_error(%{message: message}), do: message
  defp format_error(error), do: "Unexpected deploy error: #{inspect(error)}"
end
