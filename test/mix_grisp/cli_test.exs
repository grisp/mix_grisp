defmodule MixGrisp.CLITest do
  use ExUnit.Case, async: true

  test "parses task options and preserves arguments after the separator" do
    assert {[force: true, relname: "demo"], ["--quiet", "--path", "some path"]} =
             MixGrisp.CLI.parse!(
               ["--force", "-n", "demo", "--", "--quiet", "--path", "some path"],
               [force: :boolean, relname: :string],
               n: :relname
             )
  end

  test "rejects invalid switches" do
    assert_raise Mix.Error, ~r/Invalid options/, fn ->
      MixGrisp.CLI.parse!(["--unknown"], force: :boolean)
    end
  end
end
