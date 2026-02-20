defmodule MorphRu.Dawg.Completer do
  @moduledoc """
  Completes partial DAWG traversals to enumerate all keys/values
  under a given prefix.
  """

  alias MorphRu.Dawg.{Dictionary, Guide}

  @root 0

  defstruct [:dict, :guide, :key, :index_stack, :last_index, :initialized]

  def new(%Dictionary{} = dict, %Guide{} = guide) do
    %__MODULE__{dict: dict, guide: guide, initialized: false}
  end

  def start(%__MODULE__{} = c, index, prefix \\ <<>>) do
    %{c | key: prefix, index_stack: [index], last_index: @root, initialized: true}
  end

  @doc "Gets the next key-value pair. Returns `{completer, key, value}` or `:done`."
  def next(%__MODULE__{index_stack: []} = _c), do: :done

  def next(%__MODULE__{last_index: last_index} = c) when last_index != @root do
    index = hd(c.index_stack)
    child_label = Guide.child(c.guide, index)

    if child_label != 0 do
      case follow(c, child_label, index) do
        nil -> :done
        c -> find_terminal(c, hd(c.index_stack))
      end
    else
      backtrack_and_advance(c, index)
    end
  end

  def next(%__MODULE__{} = c) do
    index = hd(c.index_stack)
    find_terminal(c, index)
  end

  defp backtrack_and_advance(%__MODULE__{} = c, index) do
    sibling_label = Guide.sibling(c.guide, index)

    key = if byte_size(c.key) > 0, do: binary_part(c.key, 0, byte_size(c.key) - 1), else: c.key
    [_ | rest_stack] = c.index_stack

    case rest_stack do
      [] ->
        :done

      _ ->
        c = %{c | key: key, index_stack: rest_stack}
        parent_index = hd(rest_stack)
        advance_or_backtrack(c, sibling_label, parent_index)
    end
  end

  defp advance_or_backtrack(c, 0, parent_index), do: backtrack_and_advance(c, parent_index)

  defp advance_or_backtrack(c, sibling_label, parent_index) do
    case follow(c, sibling_label, parent_index) do
      nil -> :done
      c -> find_terminal(c, hd(c.index_stack))
    end
  end

  defp follow(%__MODULE__{} = c, label, index) do
    case Dictionary.follow_char(c.dict, label, index) do
      nil ->
        nil

      next_index ->
        %{c | key: <<c.key::binary, label>>, index_stack: [next_index | c.index_stack]}
    end
  end

  defp find_terminal(%__MODULE__{} = c, index) do
    if Dictionary.has_value?(c.dict, index) do
      c = %{c | last_index: index}
      value = Dictionary.value(c.dict, index)
      {c, c.key, value}
    else
      label = Guide.child(c.guide, index)

      case Dictionary.follow_char(c.dict, label, index) do
        nil ->
          :done

        next_index ->
          c = %{c | key: <<c.key::binary, label>>, index_stack: [next_index | c.index_stack]}
          find_terminal(c, next_index)
      end
    end
  end
end
