defmodule MixGrisp.UtilTest do
  use ExUnit.Case, async: true

  test "reads nested keyword and map configuration" do
    value = [otp: %{version: "29"}]
    assert MixGrisp.Util.get([:otp, :version], value) == "29"
    assert MixGrisp.Util.get([:otp, :jit], value, false) == false
  end

  test "ports utility artifact and destination helpers" do
    assert MixGrisp.Util.otp_cache_file_name("29.0.6", "abc") ==
             "grisp_otp_build_29.0.6_abc.tar.gz"

    assert MixGrisp.Util.filenames_join_copy_destination(%{"bin/start" => :source}, "/tmp/card") ==
             %{"/tmp/card/bin/start" => :source}
  end
end
