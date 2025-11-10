defmodule SevenGuis.Cells.Parser do
  alias SevenGuis.Cells.AstNodeTypes, as: AST

  @doc """
  Parses the user input in a cell into an expression AST.

  ## Examples

      iex> parse_formula(~c"13")
      {:int, 13}

      iex> parse_formula(~c"4.5")
      {:float, 4.5}

      iex> parse_formula(~c"Hello, world!")
      {:text, ~c"Hello, world!"}

      iex> parse_formula(~c"=7")
      {:expr, {:int, 7}}

      iex> parse_formula(~c"=8.9")
      {:expr, {:float, 8.9}}

      iex> parse_formula(~c"=B3")
      {:expr, {:coord, {1, 2}}}

      iex> parse_formula(~c"=sum(6, A5)")
      {:expr, {:appl, {:ident, ~c"sum"}, [int: 6, coord: {0, 4}]}}
  """
  @spec parse_formula(charlist()) :: AST.ast_node_formula()
  def parse_formula(text) do
    with {:ok, lexed, _} <- :formula_lexer.string(text),
         {:ok, parsed} <- :formula_parser.parse(lexed) do
      parsed
    else
      # If we don't parse in a float or an expression, parse as text
      # by pulling the entire string
      _error -> {:text, text}
    end
  end
end
