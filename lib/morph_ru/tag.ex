defmodule MorphRu.Tag do
  @moduledoc """
  An OpenCorpora morphological tag.

  A tag is a comma-separated set of grammemes like `"NOUN,anim,masc sing,nomn"`.
  The space separates the lexeme-level grammemes (POS, animacy, gender)
  from the form-level grammemes (number, case).
  """

  defstruct [:raw, :grammemes]

  @type t :: %__MODULE__{
          raw: String.t(),
          grammemes: MapSet.t(String.t())
        }

  @doc "Parses a tag string into a Tag struct."
  def parse(tag_string) when is_binary(tag_string) do
    grammemes =
      tag_string
      |> String.replace(" ", ",")
      |> String.split(",", trim: true)
      |> MapSet.new()

    %__MODULE__{raw: tag_string, grammemes: grammemes}
  end

  @doc "Checks if the tag contains a specific grammeme."
  def contains?(%__MODULE__{grammemes: grams}, grammeme), do: MapSet.member?(grams, grammeme)

  @doc "Gets the POS (part of speech) from the tag."
  @pos_tags ~w(NOUN ADJF ADJS COMP VERB INFN PRTF PRTS GRND NUMR ADVB NPRO PRED PREP CONJ PRCL INTJ)
  def pos(%__MODULE__{grammemes: grams}) do
    Enum.find(@pos_tags, fn pos -> MapSet.member?(grams, pos) end)
  end

  def to_string(%__MODULE__{raw: raw}), do: raw
end

defimpl String.Chars, for: MorphRu.Tag do
  def to_string(tag), do: tag.raw
end
