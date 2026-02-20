defmodule MorphRu.Dawg.Dictionary do
  @moduledoc """
  Double-array trie dictionary. Reads the DARTS binary format.
  """

  alias MorphRu.Dawg.Units

  @root 0

  defstruct [:units]

  @type t :: %__MODULE__{units: tuple()}

  @doc "Loads a dictionary from a binary file."
  def load(path) do
    data = File.read!(path)
    from_binary(data)
  end

  @doc "Parses dictionary from binary data."
  def from_binary(data) do
    <<base_size::little-unsigned-32, rest::binary>> = data
    units = parse_units(rest, base_size)
    %__MODULE__{units: units}
  end

  defp parse_units(data, count) do
    parse_units(data, count, [])
    |> Enum.reverse()
    |> List.to_tuple()
  end

  defp parse_units(_data, 0, acc), do: acc

  defp parse_units(<<unit::little-unsigned-32, rest::binary>>, remaining, acc) do
    parse_units(rest, remaining - 1, [unit | acc])
  end

  @doc "Checks if the key exists in the dictionary."
  def contains?(%__MODULE__{} = dict, key) when is_binary(key) do
    case follow_bytes(dict, key, @root) do
      nil -> false
      index -> has_value?(dict, index)
    end
  end

  @doc "Finds the value for an exact key match."
  def find(%__MODULE__{} = dict, key) when is_binary(key) do
    case follow_bytes(dict, key, @root) do
      nil -> -1
      index -> if has_value?(dict, index), do: value(dict, index), else: -1
    end
  end

  @doc "Follows a single byte transition."
  def follow_char(%__MODULE__{units: units}, label, index) do
    import Bitwise
    offset = Units.offset(elem(units, index))
    next_index = bxor(bxor(index, offset), label) &&& 0xFFFFFFFF

    if next_index < tuple_size(units) and Units.label(elem(units, next_index)) == label do
      next_index
    else
      nil
    end
  end

  @doc "Follows a sequence of byte transitions."
  def follow_bytes(%__MODULE__{}, <<>>, index), do: index

  def follow_bytes(%__MODULE__{} = dict, <<byte, rest::binary>>, index) do
    case follow_char(dict, byte, index) do
      nil -> nil
      next -> follow_bytes(dict, rest, next)
    end
  end

  def root, do: @root

  def has_value?(%__MODULE__{units: units}, index) do
    Units.has_leaf?(elem(units, index))
  end

  def value(%__MODULE__{units: units}, index) do
    import Bitwise
    offset = Units.offset(elem(units, index))
    value_index = bxor(index, offset) &&& 0xFFFFFFFF
    Units.value(elem(units, value_index))
  end
end
