defmodule SevenGuis.Id do
  @moduledoc """
  Handles unique ID integer generation for wx widgets.
  """

  @doc """
  Generates a unique ID integer for a term, returned in a tuple of `{term, id_integer}`.

  # Examples

      iex> generate_id(:foo)
      {:foo, 1}
  """
  @spec generate_id(term()) :: {term(), integer()}
  defp generate_id(id_name) do
    {id_name, System.unique_integer([:positive, :monotonic])}
  end

  @doc """
  Creates a map of ID names to unique ID integers.

  # Examples
      iex> generate_ids([:foo, :bar, :baz])
      %{foo: 1, bar: 2, baz: 3}
  """
  @spec generate_ids(list(term())) :: %{term() => integer()}
  def generate_ids(id_names) do
    Map.new(id_names, &generate_id/1)
  end
end
