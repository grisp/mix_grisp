defmodule MixGrisp.ProjectTestProject do
  use Mix.Project

  def project do
    [
      app: :project_test,
      version: "1.2.3",
      releases: [first: [], second: [version: "2.0.0"]],
      grisp: [platform: :grisp2, otp: [version: "29"]]
    ]
  end
end

defmodule MixGrisp.ProjectTest do
  use ExUnit.Case, async: false

  test "selects configured releases and versions" do
    assert {:second, "2.0.0"} = MixGrisp.Project.select_release("second", "2.0.0")

    assert_raise Mix.Error, ~r/Multiple releases/, fn ->
      MixGrisp.Project.select_release()
    end

    assert_raise Mix.Error, ~r/has no version/, fn ->
      MixGrisp.Project.select_release(:first, "9.9.9")
    end
  end

  test "uses rebar-compatible artifact names" do
    assert String.ends_with?(
             MixGrisp.Project.bundle_file(:first, "1.2.3"),
             "_grisp/deploy/grisp2.first.1.2.3.tar.gz"
           )

    assert String.ends_with?(
             MixGrisp.Project.firmware_file(:system, :first, "1.2.3"),
             "_grisp/firmware/grisp2.first.1.2.3.sys.gz"
           )
  end
end
