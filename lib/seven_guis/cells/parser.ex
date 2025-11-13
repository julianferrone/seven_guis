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

  @doc """
  Converts a parsed formula AST from generic map-based nodes into
  fully structured nodes using `%SevenGuis.Cells.Coord{}` and typed tuples.

  This function recursively traverses an AST produced by the formula parser,
  normalizing its representation for later evaluation.

  In particular, any coordinate maps are replaced by `%Coord{}` structs,
  and nested expressions or applications are recursively converted.

  ## Examples

      iex> alias SevenGuis.Cells.{Coord, Parser}
      iex> parsed = {:range, {:coord, %{row: 0, col: 0}}, {:coord, %{row: 1, col: 1}}}
      iex> Parser.reparse(parsed)
      {:range, %Coord{row: 0, col: 0}, %Coord{row: 1, col: 1}}

      iex> expr = {:expr, {:appl, {:ident, 'SUM'}, [{:coord, %{row: 0, col: 0}}]}}
      iex> Parser.reparse(expr)
      {:expr, {:appl, {:ident, 'SUM'}, [{:coord, %Coord{row: 0, col: 0}}]}}

  ## Pattern Clauses

    * `{:coord, coord}` — converts a coordinate map to a `%Coord{}` struct.
    * `{:range, {:coord, first}, {:coord, second}}` — converts a range of coordinates.
    * `{:expr, expr}` — recursively reparses an expression node.
    * `{:appl, ident, args}` — reparses a function application and its arguments.
    * `other` — leaves any unrecognized term unchanged.

  ## Returns

  A tuple-based AST suitable for evaluation and serialization.
  """
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
