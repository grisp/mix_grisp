defmodule MixGrisp.Configure do
  @moduledoc false

  alias MixGrisp.Configure.Renderer
  alias MixGrisp.Configure.TemplatePlan
  alias MixGrisp.Configure.Validator

  @boolean_keys [:interactive, :network, :wifi, :grisp_io, :grisp_io_linking, :epmd]

  @defaults %{
    interactive: true,
    name: nil,
    otp_version: "27",
    destination: nil,
    network: false,
    wifi: false,
    ssid: nil,
    psk: nil,
    grisp_io: false,
    grisp_io_linking: false,
    token: nil,
    epmd: false,
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
    config =
      opts
      |> merge_cli()
      |> ensure_non_interactive!()
      |> Validator.validate!()

    plan = TemplatePlan.build(config)
    result = Renderer.apply(plan, config, run_opts)

    %{config: config, plan: plan, result: result}
  end

  defp ensure_non_interactive!(%{interactive: false} = config), do: config

  defp ensure_non_interactive!(_config) do
    Mix.raise("Interactive mode is not implemented yet. Use --interactive false.")
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
end
