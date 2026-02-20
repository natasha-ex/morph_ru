defmodule MorphRu.Parse do
  @moduledoc """
  A single morphological parse result for a word.

  Contains the word form, its normal (dictionary) form,
  the morphological tag, and a probability score.
  """

  alias MorphRu.Tag

  defstruct [:word, :tag, :normal_form, :score]

  @type t :: %__MODULE__{
          word: String.t(),
          tag: Tag.t(),
          normal_form: String.t(),
          score: float()
        }
end
