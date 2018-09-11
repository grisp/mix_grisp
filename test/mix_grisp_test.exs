defmodule MixGrispTest do
  use ExUnit.Case
  doctest MixGrisp

  test "greets the world" do
    assert MixGrisp.hello() == :world
  end
end
