defmodule MixGrisp.Configure do
  @moduledoc false

  alias MixGrisp.Configure.ConfigPatcher
  alias MixGrisp.Configure.MixExsPatcher
  alias MixGrisp.Configure.Prompter
  alias MixGrisp.Configure.Renderer
  alias MixGrisp.Configure.TemplatePlan
  alias MixGrisp.Configure.Validator

  @boolean_keys [:interactive, :network, :grisp_io, :grisp_io_linking, :epmd]

  @defaults %{
    interactive: true,
    name: nil,
    otp_version: "27",
    destination: nil,
    network: false,
    network_type: nil,
    ssid: nil,
    psk: nil,
    grisp_io: false,
    grisp_io_linking: false,
    token: nil,
    epmd: false,
    node_name: nil,
    cookie: nil
  }

  def defaults do
    @defaults
  end

  def merge_cli(opts) when is_list(opts) do
    opts
    |> Enum.into(%{})
    # TODO: Reject unknown configure keys once the task/parser boundary is finalized.
    # This module currently accepts CLI-shaped input and normalizes it before running
    # the workflow; if we later call it with already-normalized state, split those paths.
    |> then(&Map.merge(defaults(), &1))
    |> normalize_booleans()
    |> Validator.normalize()
  end

  def run(opts, run_opts \\ []) when is_list(opts) and is_list(run_opts) do
    config = merge_cli(opts)

    config =
      if config.interactive do
        Prompter.maybe_prompt(config, run_opts)
      else
        default_network_type(config)
      end

    config = Validator.validate!(config)

    plan = TemplatePlan.build(config)
    result = Renderer.apply(plan, config, run_opts)
    patch_result = MixExsPatcher.apply(config, run_opts)
    config_patch_result = ConfigPatcher.apply(config, run_opts)

    %{
      config: config,
      plan: plan,
      result: result,
      patch_result: patch_result,
      config_patch_result: config_patch_result
    }
  end

  defp normalize_booleans(config) do
    Enum.reduce(@boolean_keys, config, fn key, acc ->
      Map.update!(acc, key, &normalize_boolean/1)
    end)
  end

  defp normalize_boolean(value) when value in [true, false], do: value
  defp normalize_boolean("true"), do: true
  defp normalize_boolean("false"), do: false

  defp normalize_boolean(value) do
    Mix.raise("Invalid boolean value: #{inspect(value)}")
  end

  defp default_network_type(%{network: true, network_type: nil} = config) do
    %{config | network_type: "ethernet"}
  end

  defp default_network_type(config), do: config
end
