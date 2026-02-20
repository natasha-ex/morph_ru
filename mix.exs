defmodule MorphRu.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/dannote/morph_ru"

  def project do
    [
      app: :morph_ru,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      package: package(),
      docs: docs(),
      name: "MorphRu",
      description:
        "Russian morphological analysis based on OpenCorpora dictionary. Lemmatize, inflect, POS-tag Russian words.",
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {MorphRu.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.3", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      lint: ["format --check-formatted", "credo --strict", "dialyzer"]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "MorphRu",
      source_url: @source_url,
      source_ref: "v#{@version}"
    ]
  end
end
