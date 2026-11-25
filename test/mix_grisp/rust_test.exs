defmodule MixGrisp.RustTest do
  use ExUnit.Case, async: false

  test "no Cargo input leaves applications and the target environment unchanged" do
    root = Path.join(System.tmp_dir!(), "mix-grisp-no-rust-#{System.unique_integer([:positive])}")
    apps = [{:plain, %{dir: to_charlist(root), deps: []}}]
    original = System.get_env("GRISP")
    assert MixGrisp.Rust.prepare(apps) == apps
    assert MixGrisp.Rust.with_target(apps, fn -> System.get_env("GRISP") end) == original
    refute File.exists?(Path.join(root, "_grisp"))
  end

  test "target compilation restores environment after an error" do
    before = {System.get_env("GRISP"), System.get_env("GRISP_PLATFORM")}
    apps = [{:native, %{native_nifs: [%{}]}}]

    assert_raise RuntimeError, "probe", fn ->
      MixGrisp.Rust.with_target(apps, fn ->
        assert System.get_env("GRISP") == "yes"
        raise "probe"
      end)
    end

    assert {System.get_env("GRISP"), System.get_env("GRISP_PLATFORM")} == before
  end
end
