defmodule SevenGuis.Cells.Coord do
  @moduledoc """
  Represents and manipulates spreadsheet-style cell coordinates.

  A coordinate (`%Coord{}`) consists of a **row** and **column** index,
  both zero-based integers. Helper functions are provided for creating
  coordinates and converting a range into a list of coordinates.

  This module also implements the `List.Chars` protocol to provide a
  human-readable spreadsheet-style representation (e.g., `~c"A1"`, `~c"C5"`).
  """

  alias __MODULE__

  @typedoc """
  A spreadsheet cell coordinate.

  ## Fields

    * `:row` — the zero-based row index (0 corresponds to the first row)
    * `:col` — the zero-based column index (0 corresponds to the first column)

  ## Examples

      iex> %SevenGuis.Cells.Coord{row: 0, col: 0}
      %SevenGuis.Cells.Coord{row: 0, col: 0}
  """
  @type t() :: %Coord{row: non_neg_integer(), col: non_neg_integer()}
  defstruct row: 0, col: 0

  @doc """
  Creates a new coordinate struct from a map with `:row` and `:col` keys.

  ## Examples

      iex> SevenGuis.Cells.Coord.coord(%{row: 2, col: 3})
      %SevenGuis.Cells.Coord{row: 2, col: 3}
  """
  @spec coord(%{
          row: non_neg_integer(),
          col: non_neg_integer()
        }) :: t()
  def coord(%{row: row, col: col}) do
    %Coord{row: row, col: col}
  end

  @doc """
  Creates a new coordinate struct from a row and column index.

  Both indices are zero-based.

  ## Examples

      iex> SevenGuis.Cells.Coord.coord(1, 2)
      %SevenGuis.Cells.Coord{row: 1, col: 2}
  """
  @spec coord(non_neg_integer(), non_neg_integer()) :: t()
  def coord(row, col) do
    %Coord{row: row, col: col}
  end

  @doc """
  Generates a list of coordinates representing all cells within the rectangular
  range between two coordinates (inclusive).

  The order of `first` and `second` does not matter; the function automatically
  determines the minimum and maximum bounds.

  ## Examples

      iex> c1 = SevenGuis.Cells.Coord.coord(0, 0)
      iex> c2 = SevenGuis.Cells.Coord.coord(1, 1)
      iex> SevenGuis.Cells.Coord.range_to_coords(c1, c2)
      [
        %SevenGuis.Cells.Coord{row: 0, col: 0},
        %SevenGuis.Cells.Coord{row: 0, col: 1},
        %SevenGuis.Cells.Coord{row: 1, col: 0},
        %SevenGuis.Cells.Coord{row: 1, col: 1}
      ]
  """
  @spec range_to_coords(t(), t()) :: list(t())
  def range_to_coords(first, second) do
    min_row = min(first.row, second.row)
    max_row = max(first.row, second.row)

    min_col = min(first.col, second.col)
    max_col = max(first.col, second.col)

    for row <- min_row..max_row, col <- min_col..max_col, do: coord(row, col)
  end

  defimpl List.Chars, for: Coord do
    @doc """
    Converts a coordinate to a spreadsheet-style string (e.g., `"A1"`).

    Columns are represented by letters (`A`, `B`, `C`, …),
    and rows by 1-based numbers.

    ## Examples

        iex> to_string(%SevenGuis.Cells.Coord{row: 0, col: 0})
        "A1"

        iex> to_string(%SevenGuis.Cells.Coord{row: 4, col: 2})
        "C5"
    """
    @spec to_charlist(Coord.t()) :: charlist()
    def to_charlist(coord) do
      [coord.col + ?A | ~c"#{coord.row + 1}"]
    end
  end
end
