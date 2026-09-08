defmodule MixGrisp.Pack do
  @moduledoc false

  alias MixGrisp.{Handler, Project}

  def run(options, release_args \\ []) do
    MixGrisp.ensure_started!()
    {name, version} = Project.select_release(options[:relname], options[:relvsn])
    {system, bootloader} = firmware_files(options, name, version, release_args)

    spec = %{
      name: Atom.to_string(name),
      version: to_charlist(version),
      block_size: options[:block_size] || :undefined,
      key_file: charlist_or_undefined(options[:key]),
      system: system,
      bootloader: charlist_or_undefined(bootloader),
      package: Project.update_file(name, version),
      force: Keyword.get(options, :force, false),
      handlers: Handler.handlers(&event/2)
    }

    state = spec |> :grisp_tools.pack() |> MixGrisp.finalize()
    MixGrisp.info("Package created")
    unless Keyword.get(options, :quiet, false), do: MixGrisp.info(usage(name, version))
    state
  rescue
    error in Mix.Error -> reraise(error, __STACKTRACE__)
    error -> Mix.raise("Unexpected pack error: #{inspect(error)}")
  end

  def event(event, state) do
    case event do
      [:pack, :prepare] ->
        MixGrisp.info("* Preparing and validating...")

      [:pack, :package, _, {:expanding, file}] ->
        MixGrisp.info("* Expanding compressed file #{file}")

      [:pack, :package, :create_image] ->
        MixGrisp.info("* Creating temporary disk image...")

      [:pack, :package, :create_partitions] ->
        MixGrisp.info("* Creating disk partition table...")

      [:pack, :package, :copy_firmware] ->
        MixGrisp.info("* Writing firmware...")

      [:pack, :package, :extract_manifest] ->
        MixGrisp.info("* Extracting software manifest...")

      [:pack, :package, :extract_manifest, {:manifest, :undefined}] ->
        MixGrisp.warn("Software manifest not found")

      [:pack, :package, :extract_manifest, {:manifest, manifest}] ->
        MixGrisp.info("    Using software manifest #{inspect(manifest[:id])}")

      [:pack, :package, :close_image] ->
        MixGrisp.info("* Cleaning up temporary disk image...")

      [:pack, :package, :build_package] ->
        MixGrisp.info("* Creating software update package...")

      [:pack, :package, _, {:done, path}] ->
        MixGrisp.info("    Package generated: #{MixGrisp.relative(path)}")

      _ ->
        handle_unknown(event)
    end

    {:ok, state}
  end

  defp firmware_files(options, name, version, release_args) do
    system = options[:system]
    bootloader = options[:bootloader]
    with_bootloader? = Keyword.get(options, :with_bootloader, false)

    case {system, bootloader, with_bootloader?} do
      {nil, nil, include_boot?} ->
        generated_firmware(options, name, version, release_args, include_boot?)

      {system, nil, false} ->
        {existing!(system, "System firmware"), nil}

      {system, bootloader, _} when not is_nil(system) and not is_nil(bootloader) ->
        {existing!(system, "System firmware"), existing!(bootloader, "Bootloader firmware")}

      _ ->
        Mix.raise("When supplying a bootloader, --system and --bootloader must both be explicit")
    end
  end

  defp generated_firmware(options, name, version, release_args, include_boot?) do
    system = Project.firmware_file(:system, name, version)
    boot = Project.firmware_file(:boot, name, version)
    refresh? = Keyword.get(options, :refresh, false)
    ready? = File.regular?(system) and (not include_boot? or File.regular?(boot))

    unless ready? and not refresh? do
      MixGrisp.info("* Building firmware...")

      firmware_options = [
        relname: to_string(name),
        relvsn: version,
        force: true,
        quiet: true,
        refresh: refresh?,
        bootloader: include_boot?
      ]

      MixGrisp.Firmware.run(firmware_options, release_args)
    end

    MixGrisp.info("* Using system firmware: #{MixGrisp.relative(system)}")
    if include_boot?, do: MixGrisp.info("* Using bootloader firmware: #{MixGrisp.relative(boot)}")
    {system, if(include_boot?, do: boot, else: nil)}
  end

  defp existing!(path, label) do
    unless File.regular?(path), do: Mix.raise("#{label} file not found: #{path}")
    MixGrisp.info("* Using provided #{String.downcase(label)}: #{MixGrisp.relative(path)}")
    path
  end

  defp handle_unknown(event) do
    MixGrisp.debug(event)

    case List.last(event) do
      {:error, reason, info} -> Mix.raise("Pack error #{inspect(reason)}: #{inspect(info)}")
      {:error, reason} -> Mix.raise("Pack error: #{inspect(reason)}")
      _ -> :ok
    end
  end

  defp charlist_or_undefined(nil), do: :undefined
  defp charlist_or_undefined(value), do: value

  defp usage(name, version) do
    package = MixGrisp.relative(Project.update_file(name, version))

    """
    Update package: #{package}

    Extract it under releases/#{name}/#{version}, serve the releases directory
    over HTTP, then call on the board:

        :grisp_updater.update("http://HOST:8000/#{name}/#{version}")

    Reboot and validate with `:grisp_updater.validate()`.
    """
  end
end
