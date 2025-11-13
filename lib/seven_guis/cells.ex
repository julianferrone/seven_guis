defmodule SevenGuis.Cells do
  use WxEx

  alias SevenGuis.Cells.AstNodeTypes, as: AST
  alias SevenGuis.Cells.Coord
  alias SevenGuis.Cells.ExprGraph
  alias SevenGuis.Id

  @behaviour :wx_object

  @num_rows 100
  @num_cols 26

  # deep green
  @colour_calculated {34, 118, 34}
  # warm black
  @colour_user_input {34, 34, 34}
  # grey
  @colour_empty_expr {160, 160, 160}

  @spec start_link(any()) :: {:error, any()} | {:wx_ref, any(), any(), any()}
  def start_link(notebook) do
    :wx_object.start_link(__MODULE__, [notebook], [])
  end

  def init([notebook]) do
    panel = :wxPanel.new(notebook)
    main_sizer = :wxBoxSizer.new(wxVERTICAL())
    :wxPanel.setSizer(panel, main_sizer)
    # Add grid
    grid = :wxGrid.new(panel, Id.generate_id(), style: wxTE_PROCESS_ENTER())
    :wxBoxSizer.add(main_sizer, grid)
    :wxGrid.createGrid(grid, @num_rows, @num_cols)
    :wxGrid.setDefaultCellTextColour(grid, @colour_user_input)
    :wxGrid.connect(grid, :grid_select_cell)
    :wxGrid.connect(grid, :grid_cell_changed)

    expr_graph = ExprGraph.new()

    state = %{
      panel: panel,
      grid: grid,
      expr_graph: expr_graph,
      prev_selected: Coord.coord(0, 0)
    }

    {panel, state}
  end

  def handle_event(
        wx(event: wxGrid(type: :grid_select_cell, row: row, col: col)),
        %{
          grid: grid,
          expr_graph: expr_graph,
          prev_selected: prev_selected
        } = state
      ) do
    coord = Coord.coord(row, col)
    # Change previously selected cell to show value
    display_cell_value(grid, expr_graph, prev_selected)
    # Display user input in currently selected cell
    display_cell_user_input(grid, expr_graph, coord)
    :wxGrid.forceRefresh(grid)
    state = %{state | prev_selected: coord}
    {:noreply, state}
  end

  def handle_event(
        wx(event: wxGrid(type: :grid_cell_changed, row: row, col: col)),
        %{
          panel: panel,
          grid: grid,
          expr_graph: expr_graph
        } = state
      ) do
    coord = Coord.coord(row, col)
    user_input = :wxGrid.getCellValue(grid, row, col)
    # TODO: Add a check if update_cell returns an error.
    # If so, set the values of all the cells in the cycle to something like
    # "ERROR: Cyclical references <cells in cycle1>"

    state =
      case ExprGraph.update_cell(expr_graph, coord, user_input) do
        {:ok, expr_graph, downstream} ->
          Enum.each(
            downstream,
            fn coord -> display_cell_value(grid, expr_graph, coord) end
          )

          %{state | expr_graph: expr_graph}

        {:error, cycles} ->
          # Show failure dialog
          cyclical_error_dialog(
            panel,
            expr_graph,
            coord,
            user_input,
            cycles
          )

          # Reset cell to previous value after failed
          display_cell_user_input(grid, expr_graph, coord)
          state
      end

    {:noreply, state}
  end

  def handle_event(request, state) do
    IO.inspect(request: request, state: state)
    {:noreply, state}
  end

  # __________________ Display Error Dialog __________________

  # ---------------------- Error Dialog ----------------------

  def cyclical_error_dialog(parent, expr_graph, coord, user_input, cycles) do
    previous_user_input = ExprGraph.get_user_input(expr_graph, coord)
    charlist_coord = to_charlist(coord)

    lines =
      Enum.intersperse(
        reference_lines(expr_graph, cycles, user_input),
        ~c"\n"
      )
      |> List.flatten()

    error_message = ~c"""
    Input for #{charlist_coord} has cycles:

    #{lines}

    Replacing #{charlist_coord} with previous input: \"#{previous_user_input}\"
    """

    dialog =
      :wxMessageDialog.new(
        parent,
        error_message,
        caption: ~c"ERROR: Cyclical References",
        style: wxICON_ERROR()
      )

    :wxMessageDialog.showModal(dialog)
  end

  def reference_lines(expr_graph, cycles, attempted_user_input) do
    [[first_from, first_to] | rows] =
      Enum.chunk_every(
        cycles,
        2,
        1,
        :discard
      )

    first_line = references(first_from, first_to, attempted_user_input)

    remaining_lines =
      Enum.map(rows, fn [from, to] ->
        user_input = ExprGraph.get_user_input(expr_graph, from)
        references(from, to, user_input)
      end)

    [first_line | remaining_lines]
  end

  def references(from, to, user_input) do
    from = to_charlist(from)
    to = to_charlist(to)
    ~c"#{from} refers to #{to}: \"#{user_input}\""
  end

  # _______________ Changing Cell Presentation _______________

  # Render expression values when not selected
  def display_cell_value(grid, expr_graph, coord) do
    case ExprGraph.get_formula(expr_graph, coord) do
      {:expr, _expr} ->
        case ExprGraph.get_display_value(expr_graph, coord) do
          [] ->
            user_input = ExprGraph.get_user_input(expr_graph, coord)
            :wxGrid.setCellFont(grid, coord.row, coord.col, wxITALIC_FONT())
            :wxGrid.setCellTextColour(grid, coord.row, coord.col, @colour_empty_expr)
            :wxGrid.setCellValue(grid, coord.row, coord.col, user_input)

          value ->
            :wxGrid.setCellFont(grid, coord.row, coord.col, wxNORMAL_FONT())
            :wxGrid.setCellTextColour(grid, coord.row, coord.col, @colour_calculated)
            :wxGrid.setCellValue(grid, coord.row, coord.col, value)
        end

        :wxGrid.forceRefresh(grid)

      _other ->
        display_cell_user_input(grid, expr_graph, coord)
    end
  end

  # Render expressions when selected
  def display_cell_user_input(grid, expr_graph, coord) do
    user_input = ExprGraph.get_user_input(expr_graph, coord)

    :wxGrid.setCellFont(grid, coord.row, coord.col, wxNORMAL_FONT())
    :wxGrid.setCellTextColour(grid, coord.row, coord.col, @colour_user_input)
    :wxGrid.setCellValue(grid, coord.row, coord.col, user_input)
    :wxGrid.forceRefresh(grid)
  end
end
