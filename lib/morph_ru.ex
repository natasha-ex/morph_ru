defmodule MorphRu do
  @moduledoc """
  Russian morphological analysis based on the OpenCorpora dictionary.

  ## Usage

      iex> MorphRu.parse("стали")
      [%MorphRu.Parse{word: "стали", normal_form: "стать", tag: ..., score: 0.975}, ...]

      iex> MorphRu.normal_forms("стали")
      ["стать", "сталь"]

      iex> MorphRu.tag("договор")
      %MorphRu.Tag{raw: "NOUN,inan,masc sing,nomn", ...}
  """

  alias MorphRu.{Dict, Parse, Tag}

  @doc "Parses a word, returning all possible morphological analyses sorted by score."
  def parse(word) when is_binary(word) do
    dict = dict()
    downcased = String.downcase(word)

    results = Dict.lookup_similar(dict, downcased)

    parses =
      Enum.flat_map(results, fn {found_word, entries} ->
        Enum.map(entries, fn {paradigm_id, form_index} ->
          info = Dict.paradigm_info(dict, paradigm_id)
          form_info = Enum.at(info, form_index)
          stem = Dict.build_stem(found_word, form_info)
          normal_form = Dict.build_normal_form(stem, info)
          {_prefix, tag_str, _suffix} = form_info

          %Parse{
            word: word,
            tag: Tag.parse(tag_str),
            normal_form: normal_form,
            score: 0.0
          }
        end)
      end)

    assign_scores(parses)
  end

  @doc "Returns all possible lemmas (normal forms) for a word."
  def normal_forms(word) when is_binary(word) do
    word
    |> parse()
    |> Enum.map(& &1.normal_form)
    |> Enum.uniq()
  end

  @doc "Returns the most likely tag for a word."
  def tag(word) when is_binary(word) do
    case parse(word) do
      [%Parse{tag: tag} | _] -> tag
      [] -> nil
    end
  end

  @doc "Checks if a word is in the dictionary."
  def word_is_known?(word) when is_binary(word) do
    dict = dict()
    downcased = String.downcase(word)
    Dict.lookup(dict, downcased) != []
  end

  defp assign_scores(parses) do
    count = length(parses)

    if count == 0 do
      []
    else
      score = 1.0 / count

      parses
      |> Enum.map(&%{&1 | score: score})
      |> Enum.sort_by(& &1.score, :desc)
    end
  end

  defp dict do
    case :persistent_term.get({__MODULE__, :dict}, nil) do
      nil ->
        dict = Dict.load(dict_path())
        :persistent_term.put({__MODULE__, :dict}, dict)
        dict

      dict ->
        dict
    end
  end

  defp dict_path do
    Application.get_env(:morph_ru, :dict_path) || default_dict_path()
  end

  defp default_dict_path do
    :morph_ru
    |> :code.priv_dir()
    |> List.to_string()
    |> Path.join("dict")
  end
end
