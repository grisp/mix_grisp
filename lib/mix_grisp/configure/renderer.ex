defmodule MixGrisp.Configure.Renderer do
  @moduledoc false

  def apply(plan, config, opts \\ []) when is_list(plan) and is_map(config) do
    root = Keyword.get(opts, :root, File.cwd!())

    Enum.reduce(plan, %{created: [], skipped: []}, fn entry, acc ->
      render_entry(entry, config, root, acc)
    end)
  end

  defp render_entry(%{template: template, target: target}, config, root, acc) do
    target_path = Path.join(root, target)

    if File.exists?(target_path) do
      %{acc | skipped: [target | acc.skipped]}
    else
      # For now these setup assets are copied as canonical placeholders.
      # Personalizing them from configure state can be added later if needed.
      template
      |> template_contents(config)
      |> then(&write_rendered(target_path, &1))

      %{acc | created: [target | acc.created]}
    end
  end

  defp template_contents("grisp/grisp2/common/deploy/files/grisp.ini.mustache" = template, config) do
    # Keep the base GRiSP.ini canonical and add the Wi-Fi-specific `wpa=` line only
    # when the user selected Wi-Fi networking. Likewise, append the epmd/distribution
    # flags only when that feature is enabled.
    template
    |> template_path()
    |> File.read!()
    |> maybe_add_wpa_line(config)
    |> maybe_add_epmd_flags(config)
  end

  defp template_contents(template, _config) do
    template
    |> template_path()
    |> File.read!()
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

  defp maybe_add_wpa_line(contents, %{network_type: "wifi"}) do
    String.replace(contents, "wlan=enable\n", "wlan=enable\nwpa=wpa_supplicant.conf\n")
  end

  defp maybe_add_wpa_line(contents, _config), do: contents

  defp maybe_add_epmd_flags(contents, %{epmd: true, node_name: node_name, cookie: cookie}) do
    flags =
      ~s( -kernel inetrc "./erl_inetrc" -internal_epmd epmd_sup -sname #{node_name} -setcookie #{cookie || "grisp"})

    String.replace(contents, " -extra --no-halt", flags <> " -extra --no-halt")
  end

  defp maybe_add_epmd_flags(contents, _config), do: contents
end
