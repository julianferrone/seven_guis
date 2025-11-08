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

  # ................... Parsing Coordinates ..................

  @spec parse_letters(binary()) :: {binary(), remainder_of_binary :: binary()} | :error
  def parse_letters(expr) when is_binary(expr) do
    {word, rest} =
      Enum.split_while(
        String.to_charlist(expr),
        fn x -> x in ?a..?z or x in ?A..?Z end
      )

    case word do
      [] -> :error
      str -> {str, to_string(rest)}
    end
  end

  @spec parse_coord(binary()) :: {binary(), remainder_of_binary :: binary()} | :error
  def parse_coord(expr) when is_binary(expr) do
    with {row, rest} <- parse_letters(expr),
         {column, rest2} <- Integer.parse(rest) do
      {{:coord, row, column}, rest2}
    else
      :error -> :error
    end
  end

  # ..................... Parsing Numbers ....................

  # ...................... Parsing Text ......................

  # ------------------- Parsing Combinators ------------------
end
