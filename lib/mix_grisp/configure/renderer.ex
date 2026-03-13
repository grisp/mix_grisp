defmodule MixGrisp.Configure.Renderer do
  @moduledoc false

  def apply(plan, config, opts \\ []) when is_list(plan) and is_map(config) do
    root = Keyword.get(opts, :root, File.cwd!())

    Enum.reduce(plan, %{created: [], skipped: []}, fn entry, acc ->
      render_entry(entry, config, root, acc)
    end)
  end

  defp render_entry(%{template: template, target: target}, _config, root, acc) do
    target_path = Path.join(root, target)

    if File.exists?(target_path) do
      %{acc | skipped: [target | acc.skipped]}
    else
      # For now these setup assets are copied as canonical placeholders.
      # Personalizing them from configure state can be added later if needed.
      template
      |> template_path()
      |> File.read!()
      |> then(&write_rendered(target_path, &1))

      %{acc | created: [target | acc.created]}
    end
  end

  defp template_path(template) do
    :mix_grisp
    |> :code.priv_dir()
    |> List.to_string()
    |> Path.join("templates")
    |> Path.join(template)
  end

  defp write_rendered(path, contents) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(path, contents)
  end
end
