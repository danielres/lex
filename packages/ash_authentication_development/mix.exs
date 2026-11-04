defmodule AshAuthenticationDevelopment.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_authentication_development,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ash, "~> 3.0"},
      {:ash_authentication, "~> 4.0"},
      {:plug, "~> 1.13"}
    ]
  end
end
