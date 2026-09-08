defmodule MixGrisp.ReleaseTest do
  use ExUnit.Case, async: true

  setup do
    root =
      System.tmp_dir!()
      |> Path.join("mix_grisp_release_#{System.unique_integer([:positive])}")

    File.mkdir_p!(root)
    Process.put(:relspec, %{erts: root})

    on_exit(fn -> File.rm_rf!(root) end)

    {:ok, root: root}
  end

  test "returns the only ERTS installation", %{root: root} do
    erts = Path.join(root, "erts-17.0.6")
    File.mkdir_p!(erts)

    assert MixGrisp.Release.erts() == erts
  end

  test "explains how to build a missing custom ERTS installation", %{root: root} do
    assert_raise Mix.Error, ~r/Run `mix grisp\.build`/, fn ->
      MixGrisp.Release.erts()
    end

    assert_raise Mix.Error, ~r/#{Regex.escape(Path.join(root, "erts-*"))}/, fn ->
      MixGrisp.Release.erts()
    end
  end

  test "reports multiple ERTS installations", %{root: root} do
    File.mkdir_p!(Path.join(root, "erts-17.0.5"))
    File.mkdir_p!(Path.join(root, "erts-17.0.6"))

    assert_raise Mix.Error, ~r/Multiple ERTS installations/, fn ->
      MixGrisp.Release.erts()
    end
  end
end
