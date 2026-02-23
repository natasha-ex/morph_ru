defmodule MorphRu.Dict do
  @moduledoc """
  Loads and provides access to the compiled OpenCorpora dictionary.

  The dictionary consists of:
  - `words.dawg` — maps word forms to `{paradigm_id, form_index}` pairs
  - `paradigms.array` — paradigm tables (suffix_idx, tag_idx, prefix_idx triples)
  - `gramtab-opencorpora-int.json` — tag strings indexed by number
  - `suffixes.json` — suffix strings indexed by number
  - `grammemes.json` — grammeme definitions
  - `meta.json` — dictionary metadata
  """

  alias MorphRu.Dawg.RecordDAWG

  defstruct [
    :words,
    :paradigms,
    :gramtab,
    :suffixes,
    :paradigm_prefixes,
    :meta,
    :prediction_dawgs,
    :resolved_paradigms,
    :tags
  ]

  @type t :: %__MODULE__{
          words: RecordDAWG.t(),
          paradigms: tuple(),
          gramtab: tuple(),
          suffixes: tuple(),
          paradigm_prefixes: tuple(),
          meta: map(),
          prediction_dawgs: [RecordDAWG.t()],
          resolved_paradigms: tuple(),
          tags: %{String.t() => MorphRu.Tag.t()}
        }

  @doc "Loads dictionary from the given directory path."
  def load(path) do
    meta = load_json(Path.join(path, "meta.json"))
    gramtab = load_json(Path.join(path, "gramtab-opencorpora-int.json")) |> List.to_tuple()
    suffixes = load_json(Path.join(path, "suffixes.json")) |> List.to_tuple()
    paradigms = load_paradigms(Path.join(path, "paradigms.array"))
    words = RecordDAWG.load(Path.join(path, "words.dawg"), 4)

    paradigm_prefixes =
      meta["compile_options"]["paradigm_prefixes"]
      |> List.to_tuple()

    prediction_dawgs =
      paradigm_prefixes
      |> Tuple.to_list()
      |> Enum.with_index()
      |> Enum.map(fn {_prefix, i} ->
        dawg_path = Path.join(path, "prediction-suffixes-#{i}.dawg")

        if File.exists?(dawg_path) do
          RecordDAWG.load(dawg_path, 8)
        else
          nil
        end
      end)

    tags = resolve_tags(gramtab)
    resolved = resolve_paradigms(paradigms, paradigm_prefixes, gramtab, suffixes)

    %__MODULE__{
      words: words,
      paradigms: paradigms,
      gramtab: gramtab,
      suffixes: suffixes,
      paradigm_prefixes: paradigm_prefixes,
      meta: meta,
      prediction_dawgs: prediction_dawgs,
      resolved_paradigms: resolved,
      tags: tags
    }
  end

  @doc "Looks up a word, returning `{paradigm_id, form_index}` pairs."
  def lookup(%__MODULE__{words: words}, word) do
    RecordDAWG.get(words, word)
  end

  @doc "Looks up a word with ё/е substitution."
  def lookup_similar(%__MODULE__{words: words}, word) do
    replaces = yo_replaces()
    RecordDAWG.similar_items(words, word, replaces)
  end

  @doc "Returns the resolved `{prefix, tag_str, suffix}` for a single form."
  def form_info(%__MODULE__{resolved_paradigms: resolved}, paradigm_id, form_index) do
    elem(elem(resolved, paradigm_id), form_index)
  end

  @doc "Returns the `{prefix, suffix}` of form 0 (normal form) for a paradigm."
  def normal_form_parts(%__MODULE__{resolved_paradigms: resolved}, paradigm_id) do
    {prefix, _tag_str, suffix} = elem(elem(resolved, paradigm_id), 0)
    {prefix, suffix}
  end

  @doc "Looks up a pre-parsed Tag struct by tag string."
  def get_tag(%__MODULE__{tags: tags}, tag_str) do
    Map.fetch!(tags, tag_str)
  end

  @doc "Builds paradigm info: list of `{prefix, tag, suffix}` for each form."
  def paradigm_info(%__MODULE__{resolved_paradigms: resolved}, paradigm_id) do
    resolved |> elem(paradigm_id) |> Tuple.to_list()
  end

  @doc "Builds a Tag struct for a given paradigm and form index."
  def build_tag(%__MODULE__{} = dict, paradigm_id, form_index) do
    {_prefix, tag_str, _suffix} = form_info(dict, paradigm_id, form_index)
    get_tag(dict, tag_str)
  end

  @doc "Builds the normal form for a predicted word."
  def build_normal_form(%__MODULE__{} = dict, paradigm_id, form_index, word) do
    form = form_info(dict, paradigm_id, form_index)
    stem = build_stem(word, form)
    {nf_prefix, nf_suffix} = normal_form_parts(dict, paradigm_id)
    nf_prefix <> stem <> nf_suffix
  end

  @doc "Returns the ё/е substitution map."
  def char_substitutes, do: yo_replaces()

  @doc "Extracts the stem from a word given its form info `{prefix, _tag, suffix}`."
  def build_stem(word, {prefix, _tag, suffix}) do
    prefix_len = byte_size(prefix)
    suffix_len = byte_size(suffix)
    stem_len = byte_size(word) - prefix_len - suffix_len

    if stem_len > 0 do
      binary_part(word, prefix_len, stem_len)
    else
      ""
    end
  end

  @doc "Builds the normal form from a stem and paradigm info list."
  def build_normal_form(stem, [first | _]) do
    {nf_prefix, _nf_tag, nf_suffix} = first
    nf_prefix <> stem <> nf_suffix
  end

  defp resolve_tags(gramtab) do
    for i <- 0..(tuple_size(gramtab) - 1), into: %{} do
      tag_str = elem(gramtab, i)
      {tag_str, MorphRu.Tag.parse(tag_str)}
    end
  end

  defp resolve_paradigms(paradigms, paradigm_prefixes, gramtab, suffixes) do
    for i <- 0..(tuple_size(paradigms) - 1) do
      resolve_one_paradigm(elem(paradigms, i), paradigm_prefixes, gramtab, suffixes)
    end
    |> List.to_tuple()
  end

  defp resolve_one_paradigm(para, paradigm_prefixes, gramtab, suffixes) do
    n = div(tuple_size(para), 3)

    for j <- 0..(n - 1) do
      suffix_id = elem(para, j)
      tag_id = elem(para, n + j)
      prefix_id = elem(para, 2 * n + j)
      {elem(paradigm_prefixes, prefix_id), elem(gramtab, tag_id), elem(suffixes, suffix_id)}
    end
    |> List.to_tuple()
  end

  defp load_json(path) do
    data = File.read!(path)

    case Jason.decode!(data) do
      list when is_list(list) -> ordered_list_to_map(list)
      other -> other
    end
  end

  defp ordered_list_to_map(list) when is_list(list) do
    case list do
      [[key, _value] | _] when is_binary(key) ->
        Map.new(list, fn [k, v] -> {k, ordered_list_to_map(v)} end)

      _ ->
        list
    end
  end

  defp ordered_list_to_map(other), do: other

  defp load_paradigms(path) do
    data = File.read!(path)
    <<count::little-unsigned-16, rest::binary>> = data

    parse_paradigms(rest, count, [])
    |> Enum.reverse()
    |> List.to_tuple()
  end

  defp parse_paradigms(_data, 0, acc), do: acc

  defp parse_paradigms(data, remaining, acc) do
    <<size::little-unsigned-16, rest::binary>> = data
    {values, rest} = parse_uint16_array(rest, size, [])
    paradigm = values |> Enum.reverse() |> List.to_tuple()
    parse_paradigms(rest, remaining - 1, [paradigm | acc])
  end

  defp parse_uint16_array(data, 0, acc), do: {acc, data}

  defp parse_uint16_array(<<val::little-unsigned-16, rest::binary>>, remaining, acc) do
    parse_uint16_array(rest, remaining - 1, [val | acc])
  end

  defp yo_replaces do
    %{
      "ё" => [{"е", "е"}],
      "Ё" => [{"Е", "Е"}]
    }
  end
end
