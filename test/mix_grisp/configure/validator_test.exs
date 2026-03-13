defmodule MixGrisp.Configure.ValidatorTest do
  use ExUnit.Case, async: true

  alias MixGrisp.Configure
  alias MixGrisp.Configure.Validator

  defp base_config do
    %{Configure.defaults() | name: "demo"}
  end

  test "defaults returns the base configure state" do
    assert %{
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
             cookie: nil
           } = Configure.defaults()
  end

  test "merge_cli merges options onto defaults and normalizes empty strings" do
    config =
      Configure.merge_cli(
        name: "demo",
        network: true,
        ssid: "",
        destination: ""
      )

    assert config.name == "demo"
    assert config.network
    assert config.network_type == nil
    assert config.ssid == nil
    assert config.destination == nil
    assert config.otp_version == "27"
  end

  test "merge_cli trims strings and normalizes whitespace-only optional values" do
    config =
      Configure.merge_cli(
        name: "  demo  ",
        network_type: "  wifi  ",
        ssid: "   ",
        token: "  ",
        destination: "  /tmp/grisp  "
      )

    assert config.name == "demo"
    assert config.network_type == "wifi"
    assert config.ssid == nil
    assert config.token == nil
    assert config.destination == "/tmp/grisp"
  end

  test "validator rejects blank name" do
    assert_raise Mix.Error, "--name cannot be blank", fn ->
      %{Configure.defaults() | name: ""}
      |> Validator.validate!()
    end
  end

  test "validator rejects whitespace-only name" do
    assert_raise Mix.Error, "--name cannot be blank", fn ->
      %{Configure.defaults() | name: "   "}
      |> Validator.validate!()
    end
  end

  test "validator rejects invalid network type" do
    assert_raise Mix.Error, "--network-type must be either ethernet or wifi", fn ->
      %{base_config() | network: true, network_type: "bluetooth"}
      |> Validator.validate!()
    end
  end

  test "validator rejects network type without network" do
    assert_raise Mix.Error, "--network-type requires --network", fn ->
      %{base_config() | network_type: "wifi"}
      |> Validator.validate!()
    end
  end

  test "validator rejects ssid without wifi" do
    assert_raise Mix.Error, "--ssid requires --network-type wifi", fn ->
      %{base_config() | ssid: "mywifi"}
      |> Validator.validate!()
    end
  end

  test "validator rejects psk without wifi" do
    assert_raise Mix.Error, "--psk requires --network-type wifi", fn ->
      %{base_config() | psk: "secret"}
      |> Validator.validate!()
    end
  end

  test "validator rejects grisp_io without network" do
    assert_raise Mix.Error, "--grisp-io requires --network", fn ->
      %{base_config() | grisp_io: true}
      |> Validator.validate!()
    end
  end

  test "validator rejects grisp_io_linking without grisp_io" do
    assert_raise Mix.Error, "--grisp-io-linking requires --grisp-io", fn ->
      %{base_config() | grisp_io_linking: true}
      |> Validator.validate!()
    end
  end

  test "validator rejects token without grisp_io_linking" do
    assert_raise Mix.Error, "--token requires --grisp-io-linking", fn ->
      %{base_config() | token: "token"}
      |> Validator.validate!()
    end
  end

  test "validator rejects cookie without epmd" do
    assert_raise Mix.Error, "--cookie requires --epmd", fn ->
      %{base_config() | cookie: "grisp"}
      |> Validator.validate!()
    end
  end

  test "validator accepts a valid config" do
    config =
      Configure.defaults()
      |> Map.merge(%{
        name: "demo",
        network: true,
        network_type: "wifi",
        ssid: "mywifi",
        psk: "secret",
        grisp_io: true,
        grisp_io_linking: true,
        token: "token",
        epmd: true,
        cookie: "grisp"
      })
      |> Validator.validate!()

    assert config.name == "demo"
    assert config.grisp_io
    assert config.cookie == "grisp"
  end

  test "validator allows blank optional strings after normalization" do
    config =
      base_config()
      |> Map.merge(%{
        network: true,
        network_type: "ethernet",
        token: "   ",
        cookie: "  ",
        destination: "  "
      })
      |> Validator.validate!()

    assert config.token == nil
    assert config.cookie == nil
    assert config.destination == nil
  end
end
