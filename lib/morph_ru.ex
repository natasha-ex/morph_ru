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

  alias MorphRu.{Dict, Parse, Predict, Prob}

  @doc "Parses a word, returning all possible morphological analyses sorted by score."
  def parse(word) when is_binary(word) do
    dict = dict()
    downcased = String.downcase(word)

    parses =
      dict
      |> Dict.lookup_similar(downcased)
      |> build_parses(dict, word)

    if parses == [] do
      Predict.predict(word)
    else
      prob_estimator() |> Prob.apply_to_parses(word, parses)
    end
  end

  @doc "Returns all possible lemmas (normal forms) for a word."
  def normal_forms(word) when is_binary(word) do
    word |> parse() |> Enum.map(& &1.normal_form) |> Enum.uniq()
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

  @doc "Inflects a parse to the given set of grammemes."
  def inflect(%Parse{} = parse, target_grams) when is_list(target_grams) do
    inflect(parse, MapSet.new(target_grams))
  end

  def inflect(%Parse{} = parse, %MapSet{} = target_grams) do
    dict = dict()
    paradigm_id = parse.paradigm_id
    form = Dict.form_info(dict, paradigm_id, parse.form_index)
    stem = Dict.build_stem(String.downcase(parse.word), form)

    paradigm_id
    |> find_matching_form(dict, target_grams)
    |> case do
      nil ->
        nil

      {form_index, tag} ->
        {prefix, _tag_str, suffix} = Dict.form_info(dict, paradigm_id, form_index)

        %Parse{
          word: prefix <> stem <> suffix,
          tag: tag,
          normal_form: parse.normal_form,
          score: 1.0,
          paradigm_id: paradigm_id,
          form_index: form_index
        }
    end
  end

  defp find_matching_form(paradigm_id, dict, target_grams) do
    forms = Dict.paradigm_info(dict, paradigm_id)

    forms
    |> Enum.with_index()
    |> Enum.find_value(fn {{_prefix, tag_str, _suffix}, idx} ->
      tag = Dict.get_tag(dict, tag_str)

      if MapSet.subset?(target_grams, tag.grammemes) do
        {idx, tag}
      end
    end)
  end

  defp build_parses(similar_items, dict, original_word) do
    Enum.flat_map(similar_items, fn {found_word, entries} ->
      Enum.map(entries, fn {paradigm_id, form_index} ->
        build_parse(dict, original_word, found_word, paradigm_id, form_index)
      end)
    end)
  end

  defp build_parse(dict, original_word, found_word, paradigm_id, form_index) do
    form_info = Dict.form_info(dict, paradigm_id, form_index)
    stem = Dict.build_stem(found_word, form_info)
    {nf_prefix, nf_suffix} = Dict.normal_form_parts(dict, paradigm_id)
    {_prefix, tag_str, _suffix} = form_info

    %Parse{
      word: original_word,
      tag: Dict.get_tag(dict, tag_str),
      normal_form: nf_prefix <> stem <> nf_suffix,
      score: 0.0,
      paradigm_id: paradigm_id,
      form_index: form_index
    }
  end

  @doc false
  def dict do
    case :persistent_term.get({__MODULE__, :dict}, nil) do
      nil ->
        dict = Dict.load(dict_path())
        :persistent_term.put({__MODULE__, :dict}, dict)
        dict

      dict ->
        dict
    end
  end

  defp prob_estimator do
    case :persistent_term.get({__MODULE__, :prob}, nil) do
      nil ->
        path = Path.join(dict_path(), "p_t_given_w.intdawg")
        prob = Prob.load(path)
        :persistent_term.put({__MODULE__, :prob}, prob)
        prob

      prob ->
        prob
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
