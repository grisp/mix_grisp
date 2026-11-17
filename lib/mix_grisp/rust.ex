defmodule MixGrisp.Rust do
  @moduledoc false
  @compile {:no_warn_undefined, [:cargo_opts, :grisp_tools_rust, :grisp_tools_rust_sdk]}

  alias MixGrisp.{Config, Handler, Project}

  # Cargo options belong to each owning Mix project, including path dependencies.
  def prepare(apps) do
    inputs =
      Enum.flat_map(apps, fn {app, %{dir: dir}} ->
        options = cargo_options(app, to_string(dir))
        source = Path.expand(options[:src_dir] || ".", to_string(dir))

        if File.regular?(Path.join(source, "Cargo.toml")),
          do: [%{app: app, source: source, options: options}],
          else: []
      end)

    case inputs do
      [] -> apps
      _ -> prepare(apps, inputs)
    end
  rescue
    error in Mix.Error -> reraise(error, __STACKTRACE__)
  catch
    :error, reason -> Mix.raise(format_error(reason))
  end

  # Keep Rustler's normal loader, but skip its host compiler during target builds.
  def with_target(apps, fun) do
    if Enum.any?(apps, fn {_app, info} -> Map.get(info, :native_nifs, []) != [] end) do
      previous = Map.new(["GRISP", "GRISP_PLATFORM"], &{&1, System.get_env(&1)})

      try do
        System.put_env("GRISP", "yes")
        System.put_env("GRISP_PLATFORM", to_string(Config.platform()))
        fun.()
      after
        Enum.each(previous, fn
          {key, nil} -> System.delete_env(key)
          {key, value} -> System.put_env(key, value)
        end)
      end
    else
      fun.()
    end
  end

  defp prepare(apps, inputs) do
    unless Code.ensure_loaded?(:grisp_tools_rust) and
             function_exported?(:grisp_tools_rust, :check_cargo, 0) do
      Mix.raise("Rust NIFs require a grisp_tools release with Rust support")
    end

    platform = :grisp_tools_rust.config(apps, Config.platform())
    :ok = :grisp_tools_rust.check_cargo()
    root = Project.root()

    directory =
      Path.join([root, "_grisp", to_string(Config.platform()), "rust", Config.otp_version()])

    toolchain =
      case Config.toolchain() do
        {:error, :docker_not_found} ->
          Mix.raise("Cannot access Docker; check docker info and socket permissions")

        nil ->
          Mix.raise("Rust NIFs require grisp[:build][:toolchain]")

        selected ->
          selected
      end

    sdk = :grisp_tools_rust_sdk.resolve(toolchain, root, directory, platform)
    target_dir = to_string(sdk.target_dir)

    normalized =
      Enum.map(inputs, fn input ->
        options =
          :grisp_tools_rust.defaults()
          |> Map.merge(Map.new(input.options))
          |> Map.merge(Map.new(platform.cargo_opts))
          |> Map.take([:features, :default_features, :library_types, :rustflags, :env, :target])
          |> Map.update(:features, [], &strings/1)
          |> Map.update(:library_types, [], &strings/1)
          |> Map.update(:rustflags, :undefined, &strings/1)
          |> Map.update!(:target, &to_string/1)
          |> Map.put(:path, input.source)
          |> Map.put(:target_dir, target_dir)
          |> Map.put(:toolchain, :undefined)
          |> Map.put(:release, true)

        own_env =
          Enum.map(Map.get(options, :env, []), fn {key, value} ->
            {to_charlist(key), if(value == false, do: false, else: to_charlist(value))}
          end)

        environment = own_env |> Kernel.++(sdk.env) |> Map.new() |> Enum.sort()
        cargo = :cargo_opts.new(Map.put(options, :env, environment))
        %{app: input.app, load_app: input.app, cargo: cargo}
      end)

    owner = Mix.Project.config()[:app]
    own = Enum.find(inputs, &(&1.app == owner))

    prepared =
      :grisp_tools_rust.prepare(%{
        rust: %{
          app: owner,
          inputs: normalized,
          sdk: sdk,
          workspace_manifest: if(own, do: Path.join(own.source, "Cargo.toml"), else: :undefined),
          directory: Path.join(directory, "bundle"),
          target_dir: target_dir,
          bundler: sdk.bundler,
          nm: sdk.nm
        },
        event_stack: [:rust],
        handlers: Handler.handlers(&event/2)
      })

    :grisp_tools.handlers_finalize(prepared)
    nifs = Enum.map(prepared.build.native_nifs, &host_artifacts/1)

    Enum.map(apps, fn {app, info} ->
      {app, Map.put(info, :native_nifs, Enum.filter(nifs, &(&1.app == app)))}
    end)
  end

  defp cargo_options(app, dir) do
    cond do
      dir == Project.root() ->
        Mix.Project.config()[:cargo_opts] || []

      File.regular?(Path.join(dir, "mix.exs")) ->
        Mix.Project.in_project(app, dir, fn _ -> Mix.Project.config()[:cargo_opts] || [] end)

      true ->
        []
    end
  end

  defp strings(:undefined), do: :undefined
  defp strings(values), do: Enum.map(values, &to_string/1)

  defp host_artifacts(nif) do
    crates = Enum.uniq([nif.name | nif.symbols])

    artifacts =
      for crate <- crates, extension <- [".so", ".dll"] do
        %{
          app: Map.get(nif.load_apps, crate, nif.load_app),
          path: "priv/native/#{crate}#{extension}"
        }
      end

    Map.put(nif, :host_artifacts, artifacts)
  end

  defp event([:rust, {:build, app}], state) do
    MixGrisp.info("Building Rust NIFs for #{app}")
    {:ok, state}
  end

  defp event([:rust, {:diagnostics, messages}], state) do
    Enum.each(messages, fn message ->
      diagnostic = message["message"]
      MixGrisp.info(diagnostic["rendered"] || diagnostic["message"])
    end)

    {:ok, state}
  end

  defp event(event, state) do
    MixGrisp.debug(event)
    {:ok, state}
  end

  def format_error({:rust_cargo_unsupported, missing}) do
    """
    Rust NIF inputs were found, but compatible Cargo build support is unavailable.
    Add this build-time dependency to the root project's mix.exs:

      {:cargo, git: "https://github.com/grisp/erlang-cargo.git", branch: "cross_build_support_0_1_3", runtime: false}

    Missing required APIs: #{inspect(missing)}
    """
  end

  def format_error({:rust_not_supported, platform}),
    do: "Rust NIFs are not supported for platform #{platform}"

  def format_error({:rust_sdk_missing_support, path}),
    do: "The selected toolchain does not include Rust NIF support (#{path} is missing)"

  def format_error({:rust_sdk_missing_file, path}),
    do: "The selected Rust SDK is incomplete (#{path} is missing or unusable)"

  def format_error({:rust_settings_mismatch, setting}),
    do: "Rust NIF applications must use the same #{setting} setting for the shared bundle"

  def format_error({:build_inputs_stale, _}),
    do:
      "Native build inputs differ from the installed BEAM. Run mix grisp.build before deploying."

  def format_error({:rust_bundler_failed, path, code, _}),
    do: "Rustler bundler #{path} failed (exit #{code}); see the diagnostics above"

  def format_error(reason), do: "Rust build failed: #{inspect(reason)}"
end
