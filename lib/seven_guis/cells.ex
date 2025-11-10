defmodule SevenGuis.Cells do
  use WxEx

  @behaviour :wx_object

  def start_link(notebook) do
    :wx_object.start_link(__MODULE__, [notebook], [])
  end

  def init([notebook]) do
    panel = :wxPanel.new(notebook)

    state = %{panel: panel}
    {panel, state}
  end

  def handle_event(request, state) do
    IO.inspect(request: request, state: state)
    {:noreply, state}
  end

  # ___________________ Parsing User Input ___________________

  @type ast_node_integer :: {:int, integer()}
  @type ast_node_float :: {:float, float()}
  @type ast_node_text :: {:text, charlist()}
  @type ast_node_coord :: {:coord, {integer(), integer()}}
  @type ast_node_identifier :: {:ident, charlist()}

  @type ast_node_application :: {:appl, ast_node_identifier(), list(expr())}

  @type expr ::
          ast_node_integer()
          | ast_node_float()
          | ast_node_coord()
          | ast_node_application()
  @type ast_node_expr :: {:expr, expr()}

  @type ast_node_formula ::
          ast_node_integer()
          | ast_node_float()
          | ast_node_text()
          | ast_node_expr()

  @spec parse_formula(charlist()) :: ast_node_formula()
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
