defmodule MorphRu.Prob do
  @moduledoc """
  Conditional probability estimator P(tag|word).

  Loads `p_t_given_w.intdawg` which maps `"word:TAG"` to `probability × 1_000_000`.
  """

  alias MorphRu.Dawg.IntDAWG

  @multiplier 1_000_000

  defstruct [:cpd]

  @type t :: %__MODULE__{cpd: IntDAWG.t()}

  def load(path) do
    %__MODULE__{cpd: IntDAWG.load(path)}
  end

  @doc "Returns P(tag|word) probability."
  def prob(%__MODULE__{cpd: cpd}, word, tag) when is_binary(word) and is_binary(tag) do
    key = word <> ":" <> tag
    IntDAWG.get(cpd, key, 0) / @multiplier
  end

  @doc "Applies P(t|w) scores to a list of parses, sorting by score descending."
  def apply_to_parses(%__MODULE__{} = estimator, word, parses) do
    word_lower = String.downcase(word)
    probs = Enum.map(parses, &prob(estimator, word_lower, &1.tag.raw))

    if Enum.sum(probs) == 0 do
      fallback_scores(parses)
    else
      parses
      |> Enum.zip(probs)
      |> Enum.map(fn {parse, p} -> %{parse | score: p} end)
      |> Enum.sort_by(& &1.score, :desc)
    end
  end

  defp fallback_scores(parses) do
    count = length(parses)
    if count == 0, do: [], else: Enum.map(parses, &%{&1 | score: 1.0 / count})
  end
end
