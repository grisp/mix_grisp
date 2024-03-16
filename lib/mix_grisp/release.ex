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
    release
  end
end
