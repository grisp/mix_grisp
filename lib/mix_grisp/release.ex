defmodule MixGrisp.Release do
  def erts do
    otp =
      Process.get(:relspec)
      |> Map.fetch!(:erts)

    pattern = Path.join(otp, "erts-*")

    case Path.wildcard(pattern) do
      [path] ->
        path

      [] ->
        Mix.raise("""
        No ERTS installation was found under #{otp}.

        Run `mix grisp.build` before deploying or generating firmware.
        Expected exactly one directory matching:

            #{pattern}
        """)

      paths ->
        formatted = Enum.map_join(paths, "\n", &"    #{&1}")

        Mix.raise("""
        Multiple ERTS installations were found under #{otp}; expected exactly one:

        #{formatted}
        """)
    end
  end

  def init(release) do
    Process.put(:spec, Map.take(release, [:version, :path, :name]))

    # Mix preserves an existing same-version ERTS directory, which can leave a
    # stale GRiSP OTP package in the release when the selected package changes.
    File.rm_rf!(Path.join(release.path, "erts-#{release.erts_version}"))

    release
  end
end
