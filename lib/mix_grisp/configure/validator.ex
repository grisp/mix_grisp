defmodule MixGrisp.Configure.Validator do
  @moduledoc false

  @optional_string_keys [:destination, :network_type, :ssid, :psk, :token, :node_name, :cookie]

  def normalize(config) when is_map(config) do
    Enum.reduce(@optional_string_keys, config, fn key, acc ->
      Map.update(acc, key, nil, &normalize_optional_string/1)
    end)
    |> Map.update(:name, nil, &normalize_name/1)
  end

  def validate!(config) when is_map(config) do
    config = normalize(config)

    cond do
      blank_name?(config.name) ->
        Mix.raise("--name cannot be blank")

      invalid_network_type?(config.network_type) ->
        Mix.raise("--network-type must be either ethernet or wifi")

      present?(config.network_type) && !config.network ->
        Mix.raise("--network-type requires --network")

      present?(config.ssid) && config.network_type != "wifi" ->
        Mix.raise("--ssid requires --network-type wifi")

      present?(config.psk) && config.network_type != "wifi" ->
        Mix.raise("--psk requires --network-type wifi")

      config.grisp_io && !config.network ->
        Mix.raise("--grisp-io requires --network")

      config.grisp_io_linking && !config.grisp_io ->
        Mix.raise("--grisp-io-linking requires --grisp-io")

      present?(config.token) && !config.grisp_io_linking ->
        Mix.raise("--token requires --grisp-io-linking")

      present?(config.cookie) && !config.epmd ->
        Mix.raise("--cookie requires --epmd")

      present?(config.node_name) && !config.epmd ->
        Mix.raise("--node-name requires --epmd")

      config.epmd && !present?(config.node_name) ->
        Mix.raise("--node-name is required when --epmd is enabled")

      true ->
        config
    end
  end

  defp normalize_optional_string(value) do
    value
    |> normalize_string()
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp blank_name?(value), do: value in ["", nil]
  defp invalid_network_type?(value), do: present?(value) and value not in ["ethernet", "wifi"]
  defp present?(value), do: not is_nil(value)

  defp normalize_name(value), do: normalize_string(value)

  defp normalize_string(value) when is_binary(value), do: String.trim(value)
  defp normalize_string(value), do: value
end
