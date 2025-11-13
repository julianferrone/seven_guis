defmodule SevenGuis.Cells.AstNodeTypes do
  alias SevenGuis.Cells.Coord

  @typedoc """
  Represents an integer literal node in the AST.

  ## Example
      {:int, 42}
  """
  @type ast_node_integer :: {:int, integer()}

  @typedoc """
  Represents a floating-point literal node in the AST.

  ## Example
      {:float, 3.14}
  """
  @type ast_node_float :: {:float, float()}

  @typedoc """
  Represents a numeric literal node, which can be either an integer or a float.
  """
  @type ast_node_number :: ast_node_integer() | ast_node_float()

  @typedoc """
  Represents a text literal node in the AST.

  ## Example
      {:text, ~c"hello"}
  """
  @type ast_node_text :: {:text, charlist()}

  @typedoc """
  Represents a coordinate reference node in the AST.

  This node wraps a `%SevenGuis.Cells.Coord{}` struct that refers to a single
  cell location within the spreadsheet.

  ## Example

      {:coord, %SevenGuis.Cells.Coord{row: 1, col: 2}}
      # Refers to the cell at C2
  """
  @type ast_node_coord :: {:coord, Coord.t()}

  @typedoc """
  Represents a range reference node in the AST.

  A range node defines a rectangular region between two coordinates,
  typically corresponding to a user-selected cell range like `"A1:B3"`.

  The range includes all coordinates from the top-left to the bottom-right corner,
  inclusive. The two coordinates can be provided in any order; normalization is
  handled by the evaluation layer.

  ## Example

      {:range,
        %SevenGuis.Cells.Coord{row: 0, col: 0},
        %SevenGuis.Cells.Coord{row: 2, col: 1}
      }
      # Represents the range A1:B3
  """
  @type ast_node_range :: {:range, Coord.t(), Coord.t()}

  @typedoc """
  Represents an identifier node in the AST, typically used for named references
  such as functions or variable names.

  ## Example
      {:ident, 'SUM'}
  """
  @type ast_node_identifier :: {:ident, charlist()}

  @typedoc """
  Represents a function or operator application node.

  Contains:
  - The identifier for the function/operator.
  - A list of argument expressions.

  ## Example
      {:appl, {:ident, 'SUM'}, [{:coord, {1, 1}}, {:coord, {1, 2}}]}
  """
  @type ast_node_application :: {:appl, ast_node_identifier(), list(expr())}

  @typedoc """
  Represents any valid expression node in the AST.

  Can be:
  - A number literal
  - A cell reference
  - A range reference
  - A function or operator application
  """
  @type expr ::
          ast_node_number()
          | ast_node_range()
          | ast_node_coord()
          | ast_node_application()

  @typedoc """
  Wraps an expression node with a top-level tag for uniformity.

  ## Example
      {:expr, {:appl, {:ident, 'SUM'}, [{:coord, {1, 1}}, {:coord, {1, 2}}]}}
  """
  @type ast_node_expr :: {:expr, expr()}

  @typedoc """
  Represents a literal value node in the AST.

  Can be:
  - A numeric literal
  - A text literal
  """
  @type ast_node_value() ::
          ast_node_number()
          | ast_node_text()

  @typedoc """
  Represents a complete formula node in the AST.

  A formula can be:
  - A literal value (number or text)
  - An expression (function call, reference, etc.)

  ## Example
      {:expr, {:appl, {:ident, 'SUM'}, [{:coord, {1, 1}}, {:coord, {1, 2}}]}}
  """
  @type ast_node_formula ::
          ast_node_value()
          | ast_node_expr()
end
