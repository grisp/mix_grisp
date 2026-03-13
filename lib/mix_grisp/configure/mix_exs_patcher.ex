defmodule MixGrisp.Configure.MixExsPatcher do
  @moduledoc false

  alias MixGrisp.Configure.Snippets

  @project_regex ~r/def project(?:\(\))? do\s*\[(?<body>.*?)\]/ms
  @deps_regex ~r/defp deps(?:\(\))? do\s*\[(?<body>.*?)\]/ms
  @application_regex ~r/def application(?:\(\))? do\s*\[(?<body>.*?)\]/ms

  def apply(config, opts \\ []) when is_map(config) and is_list(opts) do
    root = Keyword.get(opts, :root, File.cwd!())
    mix_exs_path = Path.join(root, "mix.exs")

    case File.read(mix_exs_path) do
      {:ok, contents} ->
        patch(mix_exs_path, contents, config)

      {:error, :enoent} ->
        %{status: :manual, updated: [], manual: manual_steps(config)}
    end
  end

  defp patch(path, contents, config) do
    with {:ok, project_patched} <- patch_project(contents),
         {:ok, deps_patched} <- patch_deps(project_patched, config),
         {:ok, application_patched} <- patch_application(deps_patched, config),
         {:ok, module_patched} <- patch_module_helpers(application_patched, config),
         true <- module_patched != contents do
      File.write!(path, module_patched)
      %{status: :updated, updated: ["mix.exs"], manual: remaining_manual_steps(config)}
    else
      false ->
        %{status: :unchanged, updated: [], manual: remaining_manual_steps(config)}

      {:error, :unsupported} ->
        %{status: :manual, updated: [], manual: manual_steps(config)}
    end
  end

  defp patch_project(contents) do
    case Regex.named_captures(@project_regex, contents) do
      %{"body" => body} ->
        body =
          body
          |> ensure_project_entry("grisp: grisp()")
          |> ensure_project_entry("releases: releases()")

        {:ok, Regex.replace(@project_regex, contents, "def project do\n    [\n#{body}\n    ]", global: false)}

      _ ->
        {:error, :unsupported}
    end
  end

  defp patch_deps(contents, config) do
    case Regex.named_captures(@deps_regex, contents) do
      %{"body" => body} ->
        body =
          body
          |> ensure_dep(~s({:grisp, "~> 2.4"}))
          |> maybe_ensure_epmd_dep(config)

        {:ok, Regex.replace(@deps_regex, contents, "defp deps do\n    [\n#{body}\n    ]", global: false)}

      _ ->
        {:error, :unsupported}
    end
  end

  defp patch_module_helpers(contents, config) do
    contents =
      contents
      |> ensure_helper("grisp", grisp_snippet(config))
      |> ensure_helper("releases", releases_snippet(config))

    {:ok, contents}
  end

  defp patch_application(contents, %{epmd: true}) do
    case Regex.named_captures(@application_regex, contents) do
      %{"body" => body} ->
        body =
          body
          |> ensure_application_entry("extra_applications: [:logger]")
          |> ensure_application_entry("included_applications: [:epmd]")

        {:ok, Regex.replace(@application_regex, contents, "def application do\n    [\n#{body}\n    ]", global: false)}

      _ ->
        {:error, :unsupported}
    end
  end

  defp patch_application(contents, _config), do: {:ok, contents}

  defp ensure_project_entry(body, entry) do
    if String.contains?(body, entry), do: body, else: append_list_line(body, entry)
  end

  defp ensure_dep(body, dep) do
    if String.contains?(body, dep), do: body, else: append_list_line(body, dep)
  end

  defp ensure_application_entry(body, entry) do
    if String.contains?(body, entry), do: body, else: append_list_line(body, entry)
  end

  defp maybe_ensure_epmd_dep(body, %{epmd: true}) do
    ensure_dep(body, Snippets.epmd_dependency())
  end

  defp maybe_ensure_epmd_dep(body, _config), do: body

  defp append_list_line(body, line) do
    trimmed = String.trim_trailing(body)

    cond do
      trimmed == "" ->
        "      #{line}"

      String.ends_with?(trimmed, ",") ->
        trimmed <> "\n      #{line}"

      true ->
        trimmed <> ",\n      #{line}"
    end
  end

  defp ensure_helper(contents, helper_name, snippet) do
    if String.contains?(contents, "def #{helper_name} do") do
      contents
    else
      contents
      |> String.trim_trailing()
      |> String.replace_suffix("end", "\n\n#{snippet}\nend")
      |> Kernel.<>("\n")
    end
  end

  defp grisp_snippet(config), do: Snippets.grisp_function(config)

  defp releases_snippet(config), do: Snippets.releases_function(config)

  defp manual_steps(config) do
    steps = [
      """
      Add to project/0:
        grisp: grisp(),
        releases: releases()
      """,
      """
      Add to deps/0:
        {:grisp, "~> 2.4"}
      """,
      grisp_snippet(config),
      releases_snippet(config)
    ]

    steps
    |> maybe_add_epmd_manual_steps(config)
    |> maybe_add_grisp_io_manual_steps(config)
  end

  defp remaining_manual_steps(%{epmd: true}) do
    [
      """
      Add epmd to your application config so its modules are available at runtime:
        extra_applications: [:logger]
        included_applications: [:epmd]
      """
    ]
  end

  defp remaining_manual_steps(_config), do: []

  defp maybe_add_epmd_manual_steps(steps, %{epmd: true}) do
    steps ++
      [
        """
        Add to deps/0:
          #{Snippets.epmd_dependency()}
        """,
        Snippets.epmd_application_manual_step()
      ]
  end

  defp maybe_add_epmd_manual_steps(steps, _config), do: steps

  defp maybe_add_grisp_io_manual_steps(steps, %{grisp_io: true}) do
    steps ++
      [
        Snippets.grisp_io_dependencies_manual_step()
      ]
  end

  defp maybe_add_grisp_io_manual_steps(steps, _config), do: steps
end
