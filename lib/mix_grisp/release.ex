defmodule MixGrisp.Release do
  def erts do
    otp =
      Process.get(:relspec)
      |> Map.fetch!(:erts)

    [name] = Path.wildcard(Path.join(otp, "erts-*"))
    name
  end

  def init(release) do
    Process.put(:spec, Map.take(release, [:version, :path, :name]))

    # Mix preserves an existing same-version ERTS directory, which can leave a
    # stale GRiSP OTP package in the release when the selected package changes.
    File.rm_rf!(Path.join(release.path, "erts-#{release.erts_version}"))

    release
  end
end
