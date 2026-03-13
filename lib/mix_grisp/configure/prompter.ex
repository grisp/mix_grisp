defmodule MixGrisp.Configure.Prompter do
  @moduledoc false

  def maybe_prompt(config, opts \\ [])
  def maybe_prompt(%{interactive: false} = config, _opts), do: config

  def maybe_prompt(config, opts) when is_map(config) and is_list(opts) do
    ask = Keyword.get(opts, :ask, &default_ask/1)

    # Some prompted values are currently validated for future use, but the generated
    # setup assets still remain canonical placeholders and are not personalized yet.
    config
    |> maybe_prompt_name(ask)
    |> maybe_prompt_network(ask)
    |> maybe_prompt_network_type(ask)
    |> maybe_prompt_ssid(ask)
    |> maybe_prompt_psk(ask)
    |> maybe_prompt_grisp_io(ask)
    |> maybe_prompt_grisp_io_linking(ask)
    |> maybe_prompt_token(ask)
    |> maybe_prompt_epmd(ask)
    |> maybe_prompt_node_name(ask)
    |> maybe_prompt_cookie(ask)
  end

  defp maybe_prompt_name(%{name: nil} = config, ask) do
    Map.put(config, :name, ask_string(ask, "OTP application name"))
  end

  defp maybe_prompt_name(config, _ask), do: config

  defp maybe_prompt_network(%{network: false} = config, ask) do
    Map.put(config, :network, ask_boolean(ask, "Enable network configuration?", false))
  end

  defp maybe_prompt_network(config, _ask), do: config

  defp maybe_prompt_network_type(%{network: true, network_type: nil} = config, ask) do
    Map.put(config, :network_type, ask_network_type(ask))
  end

  defp maybe_prompt_network_type(config, _ask), do: config

  defp maybe_prompt_ssid(%{network_type: "wifi", ssid: nil} = config, ask) do
    Map.put(config, :ssid, ask_optional_string(ask, "Wi-Fi SSID"))
  end

  defp maybe_prompt_ssid(config, _ask), do: config

  defp maybe_prompt_psk(%{network_type: "wifi", psk: nil} = config, ask) do
    Map.put(config, :psk, ask_optional_string(ask, "Wi-Fi PSK"))
  end

  defp maybe_prompt_psk(config, _ask), do: config

  defp maybe_prompt_grisp_io(%{network: true, grisp_io: false} = config, ask) do
    Map.put(config, :grisp_io, ask_boolean(ask, "Enable GRiSP.io integration?", false))
  end

  defp maybe_prompt_grisp_io(config, _ask), do: config

  defp maybe_prompt_grisp_io_linking(%{grisp_io: true, grisp_io_linking: false} = config, ask) do
    Map.put(config, :grisp_io_linking, ask_boolean(ask, "Enable GRiSP.io linking?", false))
  end

  defp maybe_prompt_grisp_io_linking(config, _ask), do: config

  defp maybe_prompt_token(%{grisp_io_linking: true, token: nil} = config, ask) do
    Map.put(config, :token, ask_optional_string(ask, "GRiSP.io linking token"))
  end

  defp maybe_prompt_token(config, _ask), do: config

  defp maybe_prompt_epmd(%{network: true, epmd: false} = config, ask) do
    Map.put(config, :epmd, ask_boolean(ask, "Enable epmd configuration?", false))
  end

  defp maybe_prompt_epmd(config, _ask), do: config

  defp maybe_prompt_node_name(%{epmd: true, node_name: nil} = config, ask) do
    Map.put(config, :node_name, ask_string(ask, "Erlang distribution node name"))
  end

  defp maybe_prompt_node_name(config, _ask), do: config

  defp maybe_prompt_cookie(%{epmd: true, cookie: nil} = config, ask) do
    Map.put(config, :cookie, ask_optional_string(ask, "Erlang distribution cookie"))
  end

  defp maybe_prompt_cookie(config, _ask), do: config

  defp ask_string(ask, label) do
    case ask.(label <> ": ") |> String.trim() do
      "" -> nil
      value -> value
    end
  end

  defp ask_optional_string(ask, label) do
    case ask.(label <> " (leave blank to skip): ") |> String.trim() do
      "" -> nil
      value -> value
    end
  end

  defp ask_boolean(ask, label, default) do
    default_hint = if default, do: "Y/n", else: "y/N"

    case ask.("#{label} [#{default_hint}]: ") |> String.trim() |> String.downcase() do
      "" -> default
      "y" -> true
      "yes" -> true
      "true" -> true
      "n" -> false
      "no" -> false
      "false" -> false
      other -> Mix.raise("Invalid prompt response: #{inspect(other)}")
    end
  end

  defp ask_network_type(ask) do
    case ask.("Network type? [ethernet/wifi]: ") |> String.trim() |> String.downcase() do
      "ethernet" -> "ethernet"
      "wifi" -> "wifi"
      other -> Mix.raise("Invalid network type: #{inspect(other)}")
    end
  end

  defp default_ask(prompt), do: Mix.shell().prompt(prompt)
end
