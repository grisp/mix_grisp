defmodule MixGrisp.Firmware do
  @moduledoc false

  alias MixGrisp.{Config, Handler, Project}

  def run(options, release_args \\ []) do
    MixGrisp.ensure_started!()
    system? = Keyword.get(options, :system, true)
    image? = Keyword.get(options, :image, false)
    boot? = Keyword.get(options, :bootloader, false)
    unless system? or image? or boot?, do: Mix.raise("No firmware selected")

    {name, version} = Project.select_release(options[:relname], options[:relvsn])
    bundle = bundle(options, name, version, release_args)
    compress? = Keyword.get(options, :compress, true)
    toolchain = toolchain(image? or boot?)

    spec = %{
      platform: Config.platform(),
      force: Keyword.get(options, :force, false),
      toolchain: toolchain,
      bundle: to_charlist(bundle),
      system: output(system?, :system, name, version, compress: compress?),
      image:
        output(image?, :image, name, version,
          compress: compress?,
          truncate: Keyword.get(options, :truncate, true)
        ),
      boot: output(boot?, :boot, name, version, compress: compress?),
      handlers: Handler.handlers(&event/2)
    }

    state = spec |> :grisp_tools.firmware() |> MixGrisp.finalize()
    MixGrisp.info("Firmware(s) created")
    unless Keyword.get(options, :quiet, false), do: MixGrisp.info(usage(spec))
    state
  rescue
    error in Mix.Error -> reraise(error, __STACKTRACE__)
    error -> Mix.raise("Unexpected firmware error: #{inspect(error)}")
  end

  def event(event, state) do
    case event do
      [:firmware, :prepare] ->
        MixGrisp.info("* Preparing and validating...")

      [:firmware, :prepare, _, {:bootloader, name}] ->
        MixGrisp.info("    Bootloader selected: #{name}")

      [:firmware, :build_firmware, :create_image] ->
        MixGrisp.info("* Creating disk image...")

      [:firmware, :build_firmware, :copy_bootloader] ->
        MixGrisp.info("* Writing bootloader...")

      [:firmware, :build_firmware, :create_partitions] ->
        MixGrisp.info("* Creating disk partition table...")

      [:firmware, :build_firmware, :format_system] ->
        MixGrisp.info("* Formatting system partitions...")

      [:firmware, :build_firmware, :deploy_bundle] ->
        MixGrisp.info("* Deploying release bundle...")

      [:firmware, :build_firmware, :extract_system] ->
        MixGrisp.info("* Extracting system firmware...")

      [:firmware, :build_firmware, :extract_image] ->
        MixGrisp.info("* Extracting image firmware...")

      [:firmware, :build_firmware, :extract_boot] ->
        MixGrisp.info("* Extracting bootloader firmware...")

      [:firmware, :build_firmware, :close_image] ->
        MixGrisp.info("* Cleaning up...")

      [:firmware, :build_firmware, kind, {:extracted, path}] ->
        MixGrisp.info("    #{kind} exported: #{MixGrisp.relative(path)}")

      _ ->
        handle_unknown(event)
    end

    {:ok, state}
  end

  defp bundle(options, name, version, release_args) do
    case options[:bundle] do
      nil ->
        path = Project.bundle_file(name, version)

        if File.regular?(path) and not Keyword.get(options, :refresh, false) do
          MixGrisp.info("* Using existing bundle: #{MixGrisp.relative(path)}")
        else
          MixGrisp.info("* Deploying bundle...")

          deploy_options =
            [tar: true, relname: to_string(name), relvsn: version]
            |> maybe_force(Keyword.get(options, :refresh, false))

          MixGrisp.Deploy.run(deploy_options, release_args)
        end

        path

      path ->
        unless File.regular?(path), do: Mix.raise("Bundle file not found: #{path}")
        MixGrisp.info("* Using provided bundle: #{MixGrisp.relative(path)}")
        path
    end
  end

  defp output(false, _type, _name, _version, _options), do: :undefined

  defp output(true, type, name, version, options) do
    options
    |> Map.new()
    |> Map.put(:target, to_charlist(Project.firmware_file(type, name, version)))
  end

  defp toolchain(false) do
    case Config.toolchain() do
      {:error, :docker_not_found} -> Mix.raise("Docker is not available")
      toolchain -> toolchain
    end
  end

  defp toolchain(true) do
    case Config.toolchain() do
      nil -> Mix.raise("A valid toolchain is required to generate image or bootloader firmware")
      {:error, :docker_not_found} -> Mix.raise("Docker is not available")
      toolchain -> toolchain
    end
  end

  defp maybe_force(options, true), do: Keyword.put(options, :force, true)
  defp maybe_force(options, false), do: options

  defp handle_unknown(event) do
    MixGrisp.debug(event)

    case List.last(event) do
      {:error, reason, info} -> Mix.raise("Firmware error #{inspect(reason)}: #{inspect(info)}")
      {:error, reason} -> Mix.raise("Firmware error: #{inspect(reason)}")
      _ -> :ok
    end
  end

  defp usage(spec) do
    files =
      [system: spec.system, image: spec.image, bootloader: spec.boot]
      |> Enum.flat_map(fn
        {_type, :undefined} -> []
        {type, %{target: target}} -> ["  #{type}: #{MixGrisp.relative(target)}"]
      end)
      |> Enum.join("\n")

    """
    Generated firmware files:
    #{files}

    Copy the required files to the GRISP SD card, unmount it, insert it in the
    board, interrupt barebox during boot, and use `uncompress` to write system
    firmware to /dev/mmc1.0 and image/bootloader firmware to /dev/mmc1.
    """
  end
end
