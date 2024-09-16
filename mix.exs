defmodule MixGrisp.MixProject do
  use Mix.Project

  @source_url "https://github.com/grisp/mix_grisp"

  def project() do
    [
      app: :mix_grisp,
      version: "0.2.0",
      description: "Mix plug-in for GRiSP.",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      source_url: @source_url
    ]
  end

  def application() do
    [
      extra_applications: [:logger, :xmerl]
    ]
  end

  defp deps() do
    [
      {:grisp_tools, "~> 2.7"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp package() do
    [
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/master/CHANGELOG.md"
      }
    ]
  end
end
