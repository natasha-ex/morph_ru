defmodule MorphRu.Dawg.Guide do
  @moduledoc """
  Guide structure for DAWG traversal. Stores child/sibling labels
  for completing partial key lookups.
  """

  defstruct [:units]

  @type t :: %__MODULE__{units: binary()}

  def from_binary(data) do
    <<base_size::little-unsigned-32, rest::binary>> = data
    units = binary_part(rest, 0, base_size * 2)
    %__MODULE__{units: units}
  end

  def child(%__MODULE__{units: units}, index) do
    :binary.at(units, index * 2)
  end

  def sibling(%__MODULE__{units: units}, index) do
    :binary.at(units, index * 2 + 1)
  end

  def size(%__MODULE__{units: units}) do
    byte_size(units)
  end
end
