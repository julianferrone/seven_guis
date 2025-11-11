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
      prev_selected: {0, 0}
    }

    {panel, state}
  end

  def handle_event(
        {:wx, _, _, _,
         {
           :wxGrid,
           :grid_select_cell,
           row,
           column,
           _,
           _,
           _,
           _,
           _,
           _
         }},
        %{
          widgets: %{grid: grid},
          expr_graph: expr_graph,
          prev_selected: prev_selected
        } = state
      ) do
    coord = {column, row}
    # Change previously selected cell to show value
    display_cell_value(grid, expr_graph, prev_selected)
    # Display user input in currently selected cell
    display_cell_user_input(grid, expr_graph, coord)

    state = %{state | prev_selected: coord}
    {:noreply, state}
  end

  def handle_event(
        {:wx, _, _, _, {:wxGrid, :grid_cell_changed, row, column, _, _, _, _, _, _}},
        %{
          widgets: %{grid: grid},
          expr_graph: expr_graph
        } = state
      ) do
    coord = {column, row}
    user_input = :wxGrid.getCellValue(grid, row, column)
    {expr_graph, downstream} = ExprGraph.update_cell(expr_graph, coord, user_input)
    Enum.each(
      downstream,
      fn coord -> display_cell_value(grid, expr_graph, coord) end
    )
    state = %{state | expr_graph: expr_graph}

    {:noreply, state}
  end

  def handle_event(request, state) do
    IO.inspect(request: request, state: state)
    {:noreply, state}
  end

  # _______________ Changing Cell Presentation _______________

  # Render expression values when not selected
  def display_cell_value(grid, expr_graph, {col, row} = coord) do
    case ExprGraph.get_formula(expr_graph, coord) do
      {:expr, _expr} ->
        value = ExprGraph.get_display_value(expr_graph, coord)
        :wxGrid.setCellTextColour(grid, row, col, @colour_calculated)
        :wxGrid.setCellValue(grid, row, col, value)

      _other ->
        :ok
    end
  end

  # Render expressions when selected
  def display_cell_user_input(grid, expr_graph, {col, row} = coord) do
    user_input = ExprGraph.get_user_input(expr_graph, coord)

    :wxGrid.setCellTextColour(grid, row, col, @colour_user_input)
    :wxGrid.setCellValue(grid, row, col, user_input)
  end
end
