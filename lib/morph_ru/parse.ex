defmodule MorphRu.Parse do
  @moduledoc """
  A single morphological parse result for a word.

  Contains the word form, its normal (dictionary) form,
  the morphological tag, and a probability score.
  """

  alias MorphRu.Tag

  defstruct [:word, :tag, :normal_form, :score, :paradigm_id, :form_index]

  @type t :: %__MODULE__{
          word: String.t(),
          tag: Tag.t(),
          normal_form: String.t(),
          score: float(),
          paradigm_id: non_neg_integer() | nil,
          form_index: non_neg_integer() | nil
        }
end
