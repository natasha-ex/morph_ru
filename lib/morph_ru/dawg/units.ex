defmodule MorphRu.Dawg.Units do
  @moduledoc """
  Bit manipulation for double-array trie units.

  Each unit is a 32-bit integer encoding:
  - Offset to child nodes (bits 10-31)
  - Extension bit (bit 9) — doubles the offset range
  - Has-leaf bit (bit 8) — indicates a value-bearing child
  - Label (bits 0-7) for non-leaf, value (bits 0-30) for leaf
  """

  import Bitwise

  @precision_mask 0xFFFFFFFF
  @is_leaf_bit 1 <<< 31
  @has_leaf_bit 1 <<< 8
  @extension_bit 1 <<< 9

  def has_leaf?(unit), do: (unit &&& @has_leaf_bit) != 0

  def value(unit), do: unit &&& (~~~@is_leaf_bit &&& @precision_mask)

  def label(unit), do: unit &&& (@is_leaf_bit ||| 0xFF)

  def offset(unit) do
    unit >>> 10 <<< ((unit &&& @extension_bit) >>> 6) &&& @precision_mask
  end
end
