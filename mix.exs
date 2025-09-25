defmodule SevenGuis.MixProject do
  use Mix.Project

  def project do
    [
      app: :seven_guis,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  def deps do
    [
      {:wx_ex, "~> 0.5.0"}
    ]
  end
end
