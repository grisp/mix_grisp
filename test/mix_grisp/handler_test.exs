defmodule MixGrisp.HandlerTest do
  use ExUnit.Case, async: true

  test "uses shell quoting and pipelines" do
    assert {{:ok, "hello world\n"}, %{marker: true}} =
             MixGrisp.Handler.shell(
               ~s[printf '%s\\n' "hello world" | sed 's/hello/hello/'],
               [],
               %{marker: true}
             )
  end

  test "returns command failures when requested" do
    assert {{:error, {7, "problem\n"}}, :state} =
             MixGrisp.Handler.shell("printf 'problem\\n'; exit 7", [:return_on_error], :state)
  end
end
