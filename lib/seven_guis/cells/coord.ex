defmodule SevenGuis.Cells.Coord do
  alias __MODULE__

  @type t() :: %Coord{row: non_neg_integer(), col: non_neg_integer()}
  defstruct row: 0, col: 0

  @spec coord(non_neg_integer(), non_neg_integer()) :: t()
  def coord(row, col) do
    %{row: row, col: col}
  end

  @spec range_to_coords(t(), t()) :: list(t())
  def range_to_coords(first, second) do
    min_row = min(first.row, second.row)
    max_row = max(first.row, second.row)

    min_col = min(first.col, second.col)
    max_col = max(first.col, second.col)

    for row <- min_row..max_row, col <- min_col..max_col, do: coord(row, col)
  end

  defimpl List.Chars, for: Coord do
    @spec to_charlist(Coord.t()) :: charlist()
    def to_charlist(coord) do
      [coord.col + ?A | ~c"#{coord.row + 1}"]
    end
  end
end
