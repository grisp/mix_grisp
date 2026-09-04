defmodule MixGrisp.Config do
  @moduledoc false

  @default_otp "29"
  @default_platform :grisp2

  def get, do: Mix.Project.config()[:grisp] || []

  def get(path, default \\ nil), do: deep_get(get(), List.wrap(path), default)

  def otp_version, do: get([:otp, :version], @default_otp) |> to_string()
  def otp_jit, do: get([:otp, :jit], false)

  def platform do
    case get(:platform) do
      nil ->
        case get(:board) do
          nil ->
            @default_platform

          board ->
            Mix.shell().info("Configuration key :board is deprecated; use :platform instead")
            normalize_atom(board)
        end

      platform ->
        normalize_atom(platform)
    end
  end

  def custom_build?, do: not is_nil(get(:build))

  def toolchain do
    directory = System.get_env("GRISP_TOOLCHAIN") || get([:build, :toolchain, :directory])
    docker = get([:build, :toolchain, :docker])

    cond do
      directory -> {:directory, to_charlist(directory)}
      docker && docker_available?() -> {:docker, to_charlist(docker)}
      docker -> {:error, :docker_not_found}
      true -> nil
    end
  end

  def deploy(option, cli_options, default \\ nil) do
    Keyword.get(cli_options, option, get([:deploy, option], default))
  end

  defp deep_get(value, [], _default), do: value

  defp deep_get(value, [key | rest], default) when is_list(value) do
    case Keyword.fetch(value, key) do
      {:ok, next} -> deep_get(next, rest, default)
      :error -> default
    end
  end

  defp deep_get(value, [key | rest], default) when is_map(value) do
    case Map.fetch(value, key) do
      {:ok, next} -> deep_get(next, rest, default)
      :error -> default
    end
  end

  defp deep_get(_value, _path, default), do: default

  defp normalize_atom(value) when is_atom(value), do: value
  defp normalize_atom(value) when is_binary(value), do: String.to_atom(value)

  defp docker_available? do
    case System.find_executable("docker") do
      nil ->
        false

      executable ->
        {_output, status} = System.cmd(executable, ["info"], stderr_to_stdout: true)
        status == 0
    end
  end
end
