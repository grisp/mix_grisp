defmodule MixGrisp.StartupTest do
  use ExUnit.Case, async: false

  test "starts build-time tools when Mix has pruned OTP dependency paths" do
    script = """
    Mix.start()
    for app <- [:ssl, :inets, :xmerl] do
      true = :code.del_path(:code.lib_dir(app, :ebin))
    end
    {:error, _} = Application.load(:xmerl)
    :ok = MixGrisp.ensure_started!()
    true = Enum.any?(Application.started_applications(), fn {app, _, _} -> app == :xmerl end)
    """

    paths = Enum.flat_map(:code.get_path(), &["-pa", to_string(&1)])
    {output, status} = System.cmd("elixir", paths ++ ["-e", script], stderr_to_stdout: true)
    assert status == 0, output
  end
end
