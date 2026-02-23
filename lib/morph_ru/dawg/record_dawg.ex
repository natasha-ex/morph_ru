defmodule MorphRu.Dawg.RecordDAWG do
  @moduledoc """
  A DAWG that stores structured records as values.

  Used by pymorphy2 to map words to lists of `{paradigm_id, form_index}` tuples.
  The binary format stores keys as UTF-8 with a `\\x01` payload separator,
  followed by base64-encoded struct-packed values.
  """

  alias MorphRu.Dawg.{Completer, Dictionary, Guide}

  @payload_separator 0x01

  defstruct [:dict, :guide, :record_size]

  @type t :: %__MODULE__{
          dict: Dictionary.t(),
          guide: Guide.t(),
          record_size: pos_integer()
        }

  @doc """
  Loads a RecordDAWG from a file.

  `record_size` is the byte size of each packed record (4 for two uint16 big-endian).
  """
  def load(path, record_size) do
    data = File.read!(path)
    from_binary(data, record_size)
  end

  @doc false
  def from_binary(data, record_size) do
    {dict, rest} = parse_dictionary(data)
    {guide, _rest} = parse_guide(rest)
    %__MODULE__{dict: dict, guide: guide, record_size: record_size}
  end

  @doc "Looks up all records for an exact key (UTF-8 string)."
  def get(%__MODULE__{} = dawg, key) when is_binary(key) do
    case Dictionary.follow_bytes(dawg.dict, key, Dictionary.root()) do
      nil ->
        []

      index ->
        case Dictionary.follow_char(dawg.dict, @payload_separator, index) do
          nil -> []
          payload_index -> collect_values(dawg, payload_index)
        end
    end
  end

  @doc """
  Looks up all records for a key and similar keys (with character substitutions).

  `replaces` is a map of `byte => [{replacement_bytes, replacement_string}]`,
  used for ё/е substitution in Russian.
  """
  def similar_items(%__MODULE__{} = dawg, key, replaces) when is_binary(key) do
    walk_similar(dawg, replaces, "", key, 0, Dictionary.root(), [])
  end

  defp walk_similar(dawg, replaces, prefix, key, pos, index, acc) when pos < byte_size(key) do
    <<_::binary-size(pos), rest::binary>> = key
    {char_bytes, char_len} = next_utf8_char(rest)

    acc =
      replaces
      |> Map.get(char_bytes, [])
      |> Enum.reduce(acc, fn {repl_bytes, repl_str}, inner ->
        try_replacement(
          dawg,
          replaces,
          prefix,
          key,
          pos,
          char_len,
          index,
          repl_bytes,
          repl_str,
          inner
        )
      end)

    case Dictionary.follow_bytes(dawg.dict, char_bytes, index) do
      nil -> acc
      next -> walk_similar(dawg, replaces, prefix, key, pos + char_len, next, acc)
    end
  end

  defp walk_similar(dawg, _replaces, prefix, key, _pos, index, acc) do
    case Dictionary.follow_char(dawg.dict, @payload_separator, index) do
      nil ->
        acc

      payload_index ->
        [{prefix <> key, collect_values(dawg, payload_index)} | acc]
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  defp try_replacement(
         dawg,
         replaces,
         prefix,
         key,
         pos,
         char_len,
         index,
         repl_bytes,
         repl_str,
         acc
       ) do
    case Dictionary.follow_bytes(dawg.dict, repl_bytes, index) do
      nil ->
        acc

      next_index ->
        new_prefix = prefix <> binary_part(key, 0, pos) <> repl_str
        remaining = binary_part(key, pos + char_len, byte_size(key) - pos - char_len)
        walk_similar(dawg, replaces, new_prefix, remaining, 0, next_index, acc)
    end
  end

  defp parse_dictionary(data) do
    <<base_size::little-unsigned-32, _rest::binary>> = data
    dict_bytes = 4 + base_size * 4
    dict_data = binary_part(data, 0, dict_bytes)
    rest = binary_part(data, dict_bytes, byte_size(data) - dict_bytes)
    {Dictionary.from_binary(dict_data), rest}
  end

  defp parse_guide(data) do
    <<base_size::little-unsigned-32, _rest::binary>> = data
    guide_bytes = 4 + base_size * 2
    guide_data = binary_part(data, 0, guide_bytes)
    rest = binary_part(data, guide_bytes, byte_size(data) - guide_bytes)
    {Guide.from_binary(guide_data), rest}
  end

  defp next_utf8_char(<<byte, _::binary>> = bin) when byte < 0x80, do: {binary_part(bin, 0, 1), 1}
  defp next_utf8_char(<<byte, _::binary>> = bin) when byte < 0xE0, do: {binary_part(bin, 0, 2), 2}
  defp next_utf8_char(<<byte, _::binary>> = bin) when byte < 0xF0, do: {binary_part(bin, 0, 3), 3}
  defp next_utf8_char(bin), do: {binary_part(bin, 0, 4), 4}

  defp collect_values(%__MODULE__{} = dawg, payload_index) do
    completer = Completer.new(dawg.dict, dawg.guide)
    completer = Completer.start(completer, payload_index)
    collect_loop(completer, dawg.record_size, [])
  end

  defp collect_loop(completer, record_size, acc) do
    case Completer.next(completer) do
      :done ->
        Enum.reverse(acc)

      {completer, key_bytes, _value} ->
        trimmed = trim_trailing(key_bytes)
        record = Base.decode64!(trimmed)
        values = decode_records(record, record_size)
        collect_loop(completer, record_size, values ++ acc)
    end
  end

  defp trim_trailing(bin) do
    size = byte_size(bin)

    if size > 0 and :binary.last(bin) == ?\n do
      binary_part(bin, 0, size - 1)
    else
      bin
    end
  end

  defp decode_records(<<>>, _size), do: []

  defp decode_records(<<a::big-unsigned-16, b::big-unsigned-16, rest::binary>>, 4) do
    [{a, b} | decode_records(rest, 4)]
  end

  defp decode_records(
         <<a::big-unsigned-16, b::big-unsigned-16, c::big-unsigned-16, rest::binary>>,
         6
       ) do
    [{a, b, c} | decode_records(rest, 6)]
  end

  defp decode_records(
         <<a::big-unsigned-32, b::big-unsigned-16, c::big-unsigned-16, rest::binary>>,
         8
       ) do
    [{a, b, c} | decode_records(rest, 8)]
  end
end
