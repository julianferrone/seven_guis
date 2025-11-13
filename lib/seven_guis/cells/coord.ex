defmodule SevenGuis.Cells.Coord do
  alias __MODULE__

  @type t() :: %Coord{row: non_neg_integer(), col: non_neg_integer()}
  defstruct row: 0, col: 0

  @spec coord(non_neg_integer(), non_neg_integer()) :: t()
  def coord(row, col) do
    %{row: row, col: col}
  end

  defimpl List.Chars, for: Coord do
    @spec to_charlist(Coord.t()) :: charlist()
    def to_charlist(coord) do
      [coord.col + ?A | ~c"#{coord.row + 1}"]
    end
  end
end
