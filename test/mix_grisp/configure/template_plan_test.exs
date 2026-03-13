defmodule MixGrisp.Configure.TemplatePlanTest do
  use ExUnit.Case, async: true

  alias MixGrisp.Configure
  alias MixGrisp.Configure.TemplatePlan

  defp targets_for(overrides) do
    Configure.defaults()
    |> Map.merge(%{name: "demo"})
    |> Map.merge(Map.new(overrides))
    |> TemplatePlan.build()
    |> Enum.map(& &1.target)
  end

  test "base plan only includes config/config.exs" do
    assert targets_for(%{}) == ["config/config.exs"]
  end

  test "network plan adds grisp.ini and erl_inetrc" do
    assert targets_for(%{network: true}) == [
             "config/config.exs",
             "grisp/grisp2/common/deploy/files/grisp.ini.mustache",
             "grisp/grisp2/common/deploy/files/erl_inetrc"
           ]
  end

  test "wifi plan adds wpa_supplicant.conf" do
    assert targets_for(%{network: true, wifi: true}) == [
             "config/config.exs",
             "grisp/grisp2/common/deploy/files/grisp.ini.mustache",
             "grisp/grisp2/common/deploy/files/wpa_supplicant.conf",
             "grisp/grisp2/common/deploy/files/erl_inetrc"
           ]
  end

  test "grisp_io skips erl_inetrc" do
    assert targets_for(%{network: true, grisp_io: true}) == [
             "config/config.exs",
             "grisp/grisp2/common/deploy/files/grisp.ini.mustache"
           ]
  end
end
