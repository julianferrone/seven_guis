defmodule SevenGuis.Cells do
  use WxEx

  alias SevenGuis.Cells.AstNodeTypes, as: AST
  alias SevenGuis.Cells.ExprGraph
  alias SevenGuis.Id

  @behaviour :wx_object

  @num_rows 100
  @num_cols 26

  # deep blue
  @colour_calculated {34, 34, 155}
  # warm black
  @colour_user_input {34, 34, 34}

  def start_link(notebook) do
    :wx_object.start_link(__MODULE__, [notebook], [])
  end

  def init([notebook]) do
    # Look:
    # ┌────────────────────────┐
    # │ ┌────────────────────┐ │
    # │ │=SUM(A3, A4)        │ │
    # │ └────────────────────┘ │
    # │ ┌──┬─────────────────┐ │
    # │ │  │                 │ │
    # │ ├──┼─────────────────┤ │
    # │ │  │                 │ │
    # │ │  │                 │ │
    # │ │  │                 │ │
    # │ │  │                 │ │
    # │ │  │                 │ │
    # │ └──┴─────────────────┘ │
    # └────────────────────────┘

    # Layout:
    # Panel
    # ┌────────────────────────┐
    # │Vertical BoxSizer       │
    # │┌──────────────────────┐│
    # ││┌────────────────────┐││
    # │││TextCtrl            │││
    # ││└────────────────────┘││
    # ││┌────────────────────┐││
    # │││Grid                │││
    # │││                    │││
    # │││                    │││
    # │││                    │││
    # ││└────────────────────┘││
    # │└──────────────────────┘│
    # └────────────────────────┘

    panel = :wxPanel.new(notebook)
    main_sizer = :wxBoxSizer.new(wxVERTICAL())
    :wxPanel.setSizer(panel, main_sizer)

    # Add text input cell
    input = :wxTextCtrl.new(panel, Id.generate_id())
    :wxBoxSizer.add(main_sizer, input)

    # Add grid
    grid = :wxGrid.new(panel, Id.generate_id(), style: wxTE_PROCESS_ENTER())
    :wxBoxSizer.add(main_sizer, grid)
    :wxGrid.createGrid(grid, @num_rows, @num_cols)
    :wxGrid.setDefaultCellTextColour(grid, @colour_user_input)
    :wxGrid.connect(grid, :grid_select_cell)
    :wxGrid.connect(grid, :grid_cell_changed)

    widgets = %{
      input: input,
      grid: grid
    }

    expr_graph = ExprGraph.new()

    state = %{
      panel: panel,
      widgets: widgets,
      expr_graph: expr_graph,
      prev_selected: {0, 0},
    }

    {panel, state}
  end

  def handle_event(request, state) do
    IO.inspect(request: request, state: state)
    {:noreply, state}
  end

  # _____________________ Text Formatting ____________________

  @spec text_colour(AST.ast_node_formula()) :: :wx.wx_colour()
  def text_colour({:expr, _expr}), do: @colour_expr
  def text_colour(_value), do: @colour_value
end
