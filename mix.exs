defmodule MixGrisp.MixProject do
  use Mix.Project

  def project do
    [
      app: :mix_grisp,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:grisp_tools, "~> 0.2"},
      {:distillery, "~> 2.0"},
    ]
  end
end
