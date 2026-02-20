defmodule MorphRu.Dawg.IntDAWG do
  @moduledoc """
  A DAWG that stores integer values for unicode keys.

  Used for P(t|w) conditional probability distributions in pymorphy2/3.
  """

  alias MorphRu.Dawg.{Dictionary, Guide}

  defstruct [:dict, :guide]

  @type t :: %__MODULE__{
          dict: Dictionary.t(),
          guide: Guide.t()
        }

  def load(path) do
    data = File.read!(path)
    from_binary(data)
  end

  def from_binary(data) do
    <<base_size::little-unsigned-32, _rest::binary>> = data
    dict_bytes = 4 + base_size * 4
    dict_data = binary_part(data, 0, dict_bytes)
    rest = binary_part(data, dict_bytes, byte_size(data) - dict_bytes)

    <<guide_size::little-unsigned-32, _::binary>> = rest
    guide_bytes = 4 + guide_size * 2
    guide_data = binary_part(rest, 0, guide_bytes)

    %__MODULE__{
      dict: Dictionary.from_binary(dict_data),
      guide: Guide.from_binary(guide_data)
    }
  end

  @doc "Gets the integer value for a key, or `default` if not found."
  def get(%__MODULE__{dict: dict}, key, default \\ 0) when is_binary(key) do
    case Dictionary.find(dict, key) do
      -1 -> default
      val -> val
    end
  end
end
