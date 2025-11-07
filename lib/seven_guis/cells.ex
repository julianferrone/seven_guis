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

  @type ast_node_coord :: {:coord, {String.t(), integer()}}
  @type ast_node_number :: {:num, float()}
  @type ast_node_text :: {:text, String.t()}

  @type function_name :: String.t()
  @type function_arguments :: [ast_node()]
  @type ast_node_function :: {:function, function_name(), function_arguments()}

  @type ast_node ::
          ast_node_coord()
        | ast_node_number()
        | ast_node_text()
        | ast_node_function()

  # -------------------- Parsing Formulae --------------------

  # ------------------- Parsing Expressions ------------------
end
