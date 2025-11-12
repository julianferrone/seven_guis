defmodule SevenGuis.Cells.AstNodeTypes do
  @type ast_node_integer :: {:int, integer()}
  @type ast_node_float :: {:float, float()}
  @type ast_node_number :: ast_node_integer() | ast_node_float()
  @type ast_node_text :: {:text, charlist()}
  @type coord() :: %{row: non_neg_integer(), col: non_neg_integer()}
  @type ast_node_coord :: {:coord, coord()}
  @type ast_node_identifier :: {:ident, charlist()}

  @type ast_node_application :: {:appl, ast_node_identifier(), list(expr())}

  @type expr ::
          ast_node_number()
          | ast_node_coord()
          | ast_node_application()
  @type ast_node_expr :: {:expr, expr()}

  @type ast_node_value() ::
          ast_node_number()
          | ast_node_text()

  @type ast_node_formula ::
          ast_node_value()
          | ast_node_expr()

  @spec coord_to_charlist(coord()) :: charlist()
  def coord_to_charlist(coord) do
    [coord.col + ?A | ~c"#{coord.row + 1}"]
  end

  @spec coord(non_neg_integer(), non_neg_integer()) :: coord()
  def coord(row, col) do
    %{row: row, col: col}
  end
end
