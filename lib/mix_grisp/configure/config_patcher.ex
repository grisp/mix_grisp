defmodule MixGrisp.Configure.ConfigPatcher do
  @moduledoc false

  alias MixGrisp.Configure.Snippets

  def apply(config, opts \\ []) when is_map(config) and is_list(opts) do
    root = Keyword.get(opts, :root, File.cwd!())
    path = Path.join(root, "config/config.exs")

    cond do
      not config.grisp_io ->
        %{status: :unchanged, updated: [], manual: []}

      not File.exists?(path) ->
        %{status: :manual, updated: [], manual: manual_steps(config)}

      true ->
        contents = File.read!(path)
        patched = patch_config(contents, config)

        if patched == contents do
          %{status: :unchanged, updated: [], manual: manual_steps(config)}
        else
          File.write!(path, patched)
          %{status: :updated, updated: ["config/config.exs"], manual: manual_steps(config)}
        end
    end
  end

  defp patch_config(contents, config) do
    # TODO: Make this patching more granular. Right now any existing
    # `config :grisp_connect` block is treated as "already configured", which can
    # skip adding other missing GRiSP.io sections such as :grisp_keychain,
    # :grisp_cryptoauth, or :grisp_updater.
    if String.contains?(contents, "config :grisp_connect") do
      contents
    else
      String.trim_trailing(contents) <> "\n\n" <> Snippets.grisp_io_config(config)
    end
  end

  defp manual_steps(config) do
    [
      Snippets.grisp_io_dependencies_manual_step(),
      Snippets.grisp_io_config_manual_step(config)
    ]
  end
end
