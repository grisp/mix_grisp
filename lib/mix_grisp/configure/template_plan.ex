defmodule MixGrisp.Configure.TemplatePlan do
  @moduledoc false

  def build(config) when is_map(config) do
    [
      %{
        template: "config/config.exs",
        target: "config/config.exs"
      }
    ]
    |> maybe_add_network(config)
    |> maybe_add_wifi(config)
    |> maybe_add_erl_inetrc(config)
  end

  defp maybe_add_network(plan, %{network: true}) do
    plan ++
      [
        %{
          template: "grisp/grisp2/common/deploy/files/grisp.ini.mustache",
          target: "grisp/grisp2/common/deploy/files/grisp.ini.mustache"
        }
      ]
  end

  defp maybe_add_network(plan, _config), do: plan

  defp maybe_add_wifi(plan, %{network_type: "wifi"}) do
    plan ++
      [
        %{
          template: "grisp/grisp2/common/deploy/files/wpa_supplicant.conf",
          target: "grisp/grisp2/common/deploy/files/wpa_supplicant.conf"
        }
      ]
  end

  defp maybe_add_wifi(plan, _config), do: plan

  defp maybe_add_erl_inetrc(plan, %{network: true, grisp_io: false}) do
    plan ++
      [
        %{
          template: "grisp/grisp2/common/deploy/files/erl_inetrc",
          target: "grisp/grisp2/common/deploy/files/erl_inetrc"
        }
      ]
  end

  defp maybe_add_erl_inetrc(plan, _config), do: plan
end
