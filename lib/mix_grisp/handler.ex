defmodule MixGrisp.Handler do
  @moduledoc false

  def shell(raw_command, options, state) do
    command = IO.iodata_to_binary(raw_command)
    MixGrisp.debug({:shell, command})

    {return_on_error, options} = pop_flag(options, :return_on_error)
    {_abort_on_error, options} = pop_flag(options, :abort_on_error)
    cmd_options = normalize_options(options)
    {output, status} = System.cmd(shell(), ["-c", command], cmd_options)
    result = if status == 0, do: {:ok, output}, else: {:error, {status, output}}

    MixGrisp.debug({:shell_result, result})

    case {result, return_on_error} do
      {{:error, {code, output}}, false} ->
        Mix.raise("Command failed with exit status #{code}:\n#{command}\n#{output}")

      _ ->
        {result, state}
    end
  end

  def handlers(event_fun, event_state \\ %{}, extra \\ %{}) do
    :grisp_tools.handlers_init(
      Map.merge(
        %{
          event: {event_fun, event_state},
          shell: {&shell/3, %{}}
        },
        extra
      )
    )
  end

  defp pop_flag(options, flag) do
    {Enum.member?(options, flag), Enum.reject(options, &(&1 == flag))}
  end

  defp normalize_options(options) do
    options
    |> Enum.flat_map(fn
      {:env, env} ->
        [{:env, Enum.map(env, fn {key, value} -> {to_string(key), to_string(value)} end)}]

      {:cd, directory} ->
        [{:cd, to_string(directory)}]

      {:use_stdout, _} ->
        []

      {:debug_abort_on_error, _} ->
        []

      option when option in [:stderr_to_stdout] ->
        [option]

      {_key, _value} = option ->
        [option]

      _ ->
        []
    end)
    |> Keyword.put_new(:stderr_to_stdout, true)
  end

  defp shell do
    System.get_env("SHELL") || if(match?({:win32, _}, :os.type()), do: "cmd.exe", else: "/bin/sh")
  end
end
