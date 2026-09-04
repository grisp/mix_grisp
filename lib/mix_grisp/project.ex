defmodule MixGrisp.Project do
  @moduledoc false

  alias Mix.Project

  def root do
    case Project.project_file() do
      nil -> File.cwd!()
      file -> file |> Path.expand() |> Path.dirname()
    end
  end

  def grisp_root, do: Path.join(root(), "_grisp")
  def report_dir, do: Path.join(grisp_root(), "report")
  def deploy_dir, do: Path.join(grisp_root(), "deploy")
  def firmware_dir, do: Path.join(grisp_root(), "firmware")
  def update_dir, do: Path.join(grisp_root(), "update")

  def releases do
    case Project.config()[:releases] || [] do
      releases when is_list(releases) ->
        releases

      other ->
        Mix.raise("Expected :releases configuration to be a keyword list, got: #{inspect(other)}")
    end
  end

  def select_release(name \\ nil, version \\ nil) do
    indexed =
      for {release_name, options} <- releases() do
        release_version =
          Keyword.get(options, :version, Project.config()[:version]) |> to_string()

        {release_name, release_version}
      end

    case indexed do
      [] -> Mix.raise(no_release_message())
      [_] -> select_from(indexed, name, version)
      _ when is_nil(name) -> Mix.raise(multiple_releases_message(indexed))
      _ -> select_from(indexed, name, version)
    end
  end

  def profiles do
    case Mix.env() do
      env when env in [:dev, :grisp, :test] -> []
      env -> [env]
    end
  end

  def profile_postfix do
    case profiles() do
      [] -> ""
      profiles -> "." <> Enum.map_join(profiles, "+", &Atom.to_string/1)
    end
  end

  def bundle_file(name, version), do: artifact(deploy_dir(), name, version, "tar.gz")
  def firmware_file(:system, name, version), do: artifact(firmware_dir(), name, version, "sys.gz")
  def firmware_file(:image, name, version), do: artifact(firmware_dir(), name, version, "emmc.gz")
  def firmware_file(:boot, name, version), do: artifact(firmware_dir(), name, version, "boot.gz")
  def update_file(name, version), do: artifact(update_dir(), name, version, "tar")

  def apps do
    old_env = Mix.env()

    try do
      Mix.env(:grisp)
      Mix.Dep.clear_cached()

      project = Project.config()
      own = {project[:app], %{dir: to_charlist(root()), deps: Project.deps_apps()}}

      dependencies =
        Mix.Dep.load_and_cache()
        |> Enum.map(fn dependency ->
          deps = Enum.map(dependency.deps, & &1.app)
          {dependency.app, %{dir: to_charlist(dependency.opts[:dest]), deps: deps}}
        end)

      dependencies ++ [own]
    after
      Mix.env(old_env)
      Mix.Dep.clear_cached()
    end
  end

  defp artifact(directory, name, version, extension) do
    platform = MixGrisp.Config.platform()
    Path.join(directory, "#{platform}.#{name}.#{version}#{profile_postfix()}.#{extension}")
  end

  defp select_from(indexed, name, version) do
    wanted_name = if name, do: normalize_name(name), else: elem(hd(indexed), 0)

    case Enum.find(indexed, fn {candidate, _} -> candidate == wanted_name end) do
      nil ->
        valid = indexed |> Enum.map(&elem(&1, 0)) |> Enum.map_join("\n  ", &to_string/1)
        Mix.raise("Unknown release #{inspect(wanted_name)}\n\nMust be one of:\n  #{valid}")

      {selected_name, selected_version} ->
        if is_nil(version) or to_string(version) == selected_version do
          {selected_name, selected_version}
        else
          Mix.raise(
            "Release #{inspect(selected_name)} has no version #{version}\n\nMust be:\n  #{selected_version}"
          )
        end
    end
  end

  defp normalize_name(name) when is_atom(name), do: name
  defp normalize_name(name), do: String.to_atom(name)

  defp no_release_message do
    app = Project.config()[:app]

    """
    No release configured.

    Add a release to mix.exs, for example:

        releases: [#{app}: [include_executables_for: [:unix]]]
    """
  end

  defp multiple_releases_message(releases) do
    examples =
      releases
      |> Enum.map(fn {name, version} ->
        "    mix grisp.deploy --relname #{name} --relvsn #{version}"
      end)
      |> Enum.join("\n")

    "Multiple releases are configured; select one with --relname and optionally --relvsn.\n\n#{examples}"
  end
end
