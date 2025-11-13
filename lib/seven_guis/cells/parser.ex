defmodule SevenGuis.Cells.Parser do
  alias SevenGuis.Cells.AstNodeTypes, as: AST
  alias SevenGuis.Cells.Coord

  @doc """
  Parses the user input in a cell into an expression AST.

  ## Examples

      iex> parse_formula(~c"")
      nil

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
      {:expr, {:coord, %{col: 1, row: 2}}}

      iex> parse_formula(~c"=A3:B5")
      {:expr, {:range, {:coord, %{col: 0, row: 2}}, {:coord, %{col: 1, row: 4}}}}

      iex> parse_formula(~c"=sum(6, A5)")
      {:expr, {:appl, {:ident, ~c"SUM"}, [int: 6, coord: %{col: 0, row: 4}]}}

  """
  @spec parse_formula(charlist()) :: AST.ast_node_formula()
  def parse_formula(~c""), do: nil

  def parse_formula(text) do
    with {:ok, lexed, _} <- :formula_lexer.string(text),
         {:ok, parsed} <- :formula_parser.parse(lexed) do
      reparse(parsed)
    else
      # If we don't parse in a float or an expression, parse as text
      # by pulling the entire string
      _error -> {:text, text}
    end
    |> IO.inspect(label: "parsed")
  end

  # Convert parsed formula from maps to structs
  def reparse({:coord, coord}), do: {:coord, Coord.coord(coord)}
  def reparse({:expr, expr}), do: {:expr, reparse(expr)}

  def reparse({:range, {:coord, first}, {:coord, second}}) do
    {:range, Coord.coord(first), Coord.coord(second)}
  end

  def reparse({:appl, ident, args}) do
    {:appl, reparse(ident), Enum.map(args, &reparse/1)}
  end

  def reparse(other), do: other
end
