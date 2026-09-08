defmodule MixGrisp.Util do
  @moduledoc false

  alias MixGrisp.{Config, Handler, Project}

  defdelegate apps(), to: Project
  defdelegate root(), to: Project, as: :grisp_root
  defdelegate report_dir(), to: Project
  defdelegate deploy_dir(), to: Project
  defdelegate firmware_dir(), to: Project
  defdelegate update_dir(), to: Project
  defdelegate config(), to: Config, as: :get
  defdelegate otp_version(), to: Config
  defdelegate otp_jit(), to: Config
  defdelegate platform(), to: Config
  defdelegate should_build(), to: Config, as: :custom_build?
  defdelegate toolchain_root(), to: Config, as: :toolchain
  defdelegate select_release(name, version), to: Project
  defdelegate bundle_file_path(name, version), to: Project, as: :bundle_file
  defdelegate firmware_file_path(type, name, version), to: Project, as: :firmware_file
  defdelegate update_file_path(name, version), to: Project, as: :update_file

  def debug(term), do: MixGrisp.debug(term)
  def info(message), do: MixGrisp.info(message)
  def warn(message), do: MixGrisp.warn(message)
  def abort(message), do: Mix.raise(to_string(message))

  def shell(command, options \\ []) do
    {result, _state} = Handler.shell(command, options, %{})
    result
  end

  def get(path, term, default \\ nil), do: deep_get(term, List.wrap(path), default)

  def filenames_join_copy_destination(from_to, root) do
    Map.new(from_to, fn {target, source} -> {Path.join(root, to_string(target)), source} end)
  end

  def otp_build_root(version), do: Path.join([root(), "otp", to_string(version), "build"])

  def otp_build_install_root(version),
    do: Path.join([root(), "otp", to_string(version), "install"])

  def otp_cache_file_name(version, hash), do: "grisp_otp_build_#{version}_#{hash}.tar.gz"
  def otp_hash_listing_path(install_root), do: Path.join(install_root, "GRISP_PACKAGE_FILES")

  def bundle_file_name(name, version), do: Project.bundle_file(name, version) |> Path.basename()

  def firmware_file_name(type, name, version),
    do: Project.firmware_file(type, name, version) |> Path.basename()

  def update_file_name(name, version), do: Project.update_file(name, version) |> Path.basename()

  def ensure_dir(file) do
    case File.mkdir_p(Path.dirname(to_string(file))) do
      :ok -> :ok
      {:error, reason} -> Mix.raise("Could not create target directory: #{inspect(reason)}")
    end
  end

  defp deep_get(value, [], _default), do: value

  defp deep_get(value, [key | rest], default) when is_map(value) do
    case Map.fetch(value, key) do
      {:ok, next} -> deep_get(next, rest, default)
      :error -> default
    end
  end

  defp deep_get(value, [key | rest], default) when is_list(value) do
    case Keyword.fetch(value, key) do
      {:ok, next} -> deep_get(next, rest, default)
      :error -> default
    end
  end

  defp deep_get(_value, _path, default), do: default
end
