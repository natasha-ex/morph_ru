defmodule MorphRu.Predict do
  @moduledoc """
  Unknown word prediction using suffix analysis.

  When a word isn't found in the dictionary, predicts its morphological
  properties by matching suffixes against known paradigm patterns.

  Uses `prediction-suffixes-{0,1,2}.dawg` files corresponding to
  paradigm prefixes `["", "по", "наи"]`.
  """

  alias MorphRu.{Dict, Parse, Tag}
  alias MorphRu.Dawg.RecordDAWG

  @score_multiplier 0.5

  @doc "Predicts morphological parses for an unknown word."
  def predict(word) do
    word_lower = String.downcase(word)
    dict = MorphRu.dict()
    config = dict.meta

    max_suffix_length = get_max_suffix_length(config)
    paradigm_prefixes = get_paradigm_prefixes(config)
    suffix_dawgs = dict.prediction_dawgs
    replaces = Dict.char_substitutes()

    prefixes_rev = paradigm_prefixes |> Enum.with_index() |> Enum.reverse()
    splits = Enum.to_list(max_suffix_length..1//-1)

    seen = MapSet.new()
    total_counts = List.duplicate(1, length(paradigm_prefixes)) |> :array.from_list()

    {results, _seen, total_counts} =
      Enum.reduce(prefixes_rev, {[], seen, total_counts}, fn {prefix, prefix_id}, acc ->
        if String.starts_with?(word_lower, prefix) do
          dawg = Enum.at(suffix_dawgs, prefix_id)
          predict_with_prefix(word_lower, dawg, prefix_id, splits, replaces, dict, acc)
        else
          acc
        end
      end)

    results
    |> Enum.map(fn {cnt, fixed_word, tag, normal_form, prefix_id, para_id, form_idx} ->
      tc = :array.get(prefix_id, total_counts)
      score = cnt / tc * @score_multiplier

      %Parse{
        word: fixed_word,
        tag: tag,
        normal_form: normal_form,
        score: score,
        paradigm_id: para_id,
        form_index: form_idx
      }
    end)
    |> Enum.sort_by(& &1.score, :desc)
  end

  defp predict_with_prefix(
         word_lower,
         dawg,
         prefix_id,
         splits,
         replaces,
         dict,
         {results, seen, total_counts}
       ) do
    Enum.reduce_while(splits, {results, seen, total_counts}, fn i, {res, seen, tc} ->
      suf_len = min(i, String.length(word_lower))
      word_end = String.slice(word_lower, -suf_len, suf_len)
      word_start = String.slice(word_lower, 0, String.length(word_lower) - suf_len)

      para_data = RecordDAWG.similar_items(dawg, word_end, replaces)

      {new_res, new_seen, new_tc} =
        Enum.reduce(para_data, {res, seen, tc}, fn {fixed_suffix, parses}, {r, s, t} ->
          fixed_word = word_start <> fixed_suffix

          Enum.reduce(parses, {r, s, t}, fn {cnt, para_id, form_idx}, {r2, s2, t2} ->
            tag = Dict.build_tag(dict, para_id, form_idx)

            if productive_tag?(tag) do
              key = {fixed_word, tag.raw, para_id}

              if MapSet.member?(s2, key) do
                {r2, s2, :array.set(prefix_id, :array.get(prefix_id, t2) + cnt, t2)}
              else
                normal_form = Dict.build_normal_form(dict, para_id, form_idx, fixed_word)

                entry = {cnt, fixed_word, tag, normal_form, prefix_id, para_id, form_idx}

                {[entry | r2], MapSet.put(s2, key),
                 :array.set(prefix_id, :array.get(prefix_id, t2) + cnt, t2)}
              end
            else
              {r2, s2, t2}
            end
          end)
        end)

      if :array.get(prefix_id, new_tc) > 1 do
        {:halt, {new_res, new_seen, new_tc}}
      else
        {:cont, {new_res, new_seen, new_tc}}
      end
    end)
  end

  @non_productive_tags MapSet.new(~w(NUMR NPRO PRED PREP CONJ PRCL INTJ))

  defp productive_tag?(%Tag{} = tag) do
    not Enum.any?(@non_productive_tags, &MapSet.member?(tag.grammemes, &1))
  end

  defp get_max_suffix_length(meta) do
    cond do
      is_map(meta["compile_options"]) -> meta["compile_options"]["max_suffix_length"]
      is_map(meta["prediction_options"]) -> meta["prediction_options"]["max_suffix_length"]
      true -> 5
    end
  end

  defp get_paradigm_prefixes(meta) do
    meta["paradigm_prefixes"] || ["", "по", "наи"]
  end
end
