defmodule MixGrisp.Configure do
  @moduledoc false

  alias MixGrisp.Configure.Validator

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
    # TODO: Item 2: reject unknown configure keys once the task/parser boundary is in place.
    |> then(&Map.merge(defaults(), &1))
    |> Validator.normalize()
  end
end
