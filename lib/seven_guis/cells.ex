defmodule SevenGuis.Cells do
  @moduledoc """
  Spreadsheet GUI component using WxEx.

  This module implements a `:wx_object` behaviour to create and manage
  a spreadsheet-like grid interface. The spreadsheet is backed by an
  `ExprGraph` that tracks user input, parsed formulas, calculated
  values, and dependencies.

  Features include:

    * A configurable grid of cells (`@num_rows` × `@num_cols`)
    * Cell selection and editing events
    * Automatic evaluation of formulas via `ExprGraph`
    * Color-coded cell content:
      - Deep green (`@colour_calculated`) for calculated values
      - Warm black (`@colour_user_input`) for user-entered values
      - Grey (`@colour_empty_expr`) for empty cells
  """
  use WxEx

  alias SevenGuis.Cells.Coord
  alias SevenGuis.Cells.ExprGraph
  alias SevenGuis.Id

  @behaviour :wx_object

  @num_rows 100
  @num_cols 26

  @colour_calculated {34, 118, 34}
  # warm black
  @colour_user_input {34, 34, 34}
  # grey
  @colour_empty_expr {160, 160, 160}

  @doc """
  Starts the spreadsheet GUI process linked to the calling process.

  ## Parameters

    * `notebook` — a WxEx notebook (tabbed container) to host the spreadsheet panel

  ## Returns

    * `{:error, reason}` — if process creation failed
    * `{:wx_ref, module, pid, state}` — on successful creation

  ## Example

      iex> {:wx_ref, _module, pid, _state} = SevenGuis.Cells.Grid.start_link(notebook)
  """
  @spec start_link(any()) :: {:error, any()} | {:wx_ref, any(), any(), any()}
  def start_link(notebook) do
    :wx_object.start_link(__MODULE__, [notebook], [])
  end

  @doc """
  Initializes the spreadsheet panel and grid.

  Sets up the panel, sizer, and grid with default properties, attaches
  event handlers, and initializes an empty `ExprGraph` for managing
  cell values and dependencies.

  ## Parameters

    * `[notebook]` — a single-element list containing the notebook to host the panel

  ## Returns

    * `{panel, state}` — the panel reference and initial state map

  ## State Keys

    * `:panel` — the WxEx panel containing the grid
    * `:grid` — the WxEx grid control
    * `:expr_graph` — the `ExprGraph` managing spreadsheet data
    * `:prev_selected` — the previously selected cell (`Coord.t()`), initialized to `{0, 0}`

  ## Example

      iex> {panel, state} = SevenGuis.Cells.Grid.init([notebook])
      iex> state.expr_graph
      %SevenGuis.Cells.ExprGraph{cells: %{}, subscribers: %{}}
  """
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

  # _____________________ Handling Events ____________________

  # ------------------- User Selected Cell -------------------

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

  # -------------------- User Changed Cell -------------------

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
          dialog_error_cyclical(
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

  @doc """
  Displays a modal error dialog when a user input introduces a cyclical dependency.

  This function informs the user that the attempted input would create a
  cycle in the spreadsheet's dependency graph. It shows which cells
  reference each other and reverts the edited cell to its previous value.

  ## Parameters

    * `parent` — the parent WxEx window for the dialog
    * `expr_graph` — the `%ExprGraph{}` containing current cell data
    * `coord` — the `%Coord{}` of the cell where the cycle was attempted
    * `user_input` — the attempted input that caused the cycle
    * `cycles` — a list of `%Coord{}` forming the cyclical dependency

  ## Returns

    * The result of `:wxMessageDialog.showModal/1` (typically `wxID_OK`)
  """
  @spec dialog_error_cyclical(
          :wxWindow.wxWindow(),
          ExprGraph.t(),
          Coord.t(),
          charlist(),
          [
            Coord.t()
          ]
        ) ::
          integer()
  def dialog_error_cyclical(parent, expr_graph, coord, user_input, cycles) do
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

  @doc """
  Generates a list of formatted lines describing cell references in a cycle.

  Each line describes which cell refers to which, including the user input
  that caused the reference. Used by `cyclical_error_dialog/5`.

  ## Parameters

    * `expr_graph` — the `%ExprGraph{}` containing cell data
    * `cycles` — a list of `%Coord{}` forming the cycle
    * `attempted_user_input` — the user input that triggered the cycle

  ## Returns

    * A list of charlists representing each reference in the cycle
  """
  @spec reference_lines(ExprGraph.t(), [Coord.t()], charlist()) :: [charlist()]
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

  @doc """
  Formats a single reference line describing that one cell refers to another.

  ## Parameters

    * `from` — the `%Coord{}` of the referring cell
    * `to` — the `%Coord{}` of the referred cell
    * `user_input` — the user input in the `from` cell

  ## Returns

    * A charlist representing the reference in human-readable form

  ## Example

      iex> references(%Coord{row: 0, col: 0}, %Coord{row: 0, col: 1}, ~c"=B1")
      ~c"0:0 refers to 0:1: \"=B1\""
  """
  @spec references(Coord.t(), Coord.t(), charlist()) :: charlist()
  def references(from, to, user_input) do
    from = to_charlist(from)
    to = to_charlist(to)
    ~c"#{from} refers to #{to}: \"#{user_input}\""
  end

  # _______________ Changing Cell Presentation _______________

  @doc """
  Displays the calculated value of a cell in the grid.

  This function is used when a cell loses focus or when the grid needs
  to show the result of a formula. Depending on the cell's state, it
  either shows the evaluated value, a placeholder for empty expressions,
  or the user input for non-formula cells.

  ## Parameters

    * `grid` — the WxEx grid control
    * `expr_graph` — the `%ExprGraph{}` containing cell formulas and values
    * `coord` — the `%Coord{}` of the cell to update

  ## Behavior

    1. Checks if the cell contains a formula:
        * If so, gets its display value:
            - If empty (`[]`), shows the user input in italic grey.
            - If a value exists, shows it in normal font and deep green.
        * Forces the grid to refresh.
    2. If the cell is not a formula, falls back to displaying the user input
       using `display_cell_user_input/3`.

  ## Example

      iex> display_cell_value(grid, expr_graph, %Coord{row: 0, col: 0})
      :ok
  """
  @spec display_cell_value(:wxGrid.grid(), ExprGraph.t(), Coord.t()) :: :ok
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

  @doc """
  Displays the user-entered input in a specific cell of the grid.

  This function is used when a cell is selected, so that the user
  sees the raw input they typed rather than the calculated value.

  ## Parameters

    * `grid` — the WxEx grid control
    * `expr_graph` — the `%ExprGraph{}` containing cell values and formulas
    * `coord` — the `%Coord{}` of the cell to update

  ## Behavior

    1. Retrieves the user input for the specified cell from `ExprGraph`.
    2. Sets the cell font to normal (`wxNORMAL_FONT()`).
    3. Sets the cell text color to `@colour_user_input` (warm black).
    4. Updates the cell value in the grid to show the user input.
    5. Forces a grid refresh to apply the changes immediately.

  ## Example

      iex> display_cell_user_input(grid, expr_graph, %Coord{row: 0, col: 0})
      :ok
  """
  @spec display_cell_user_input(:wxGrid.grid(), ExprGraph.t(), Coord.t()) :: :ok
  def display_cell_user_input(grid, expr_graph, coord) do
    user_input = ExprGraph.get_user_input(expr_graph, coord)

    :wxGrid.setCellFont(grid, coord.row, coord.col, wxNORMAL_FONT())
    :wxGrid.setCellTextColour(grid, coord.row, coord.col, @colour_user_input)
    :wxGrid.setCellValue(grid, coord.row, coord.col, user_input)
    :wxGrid.forceRefresh(grid)
  end
end
