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

  @type parse_result(success) :: {success, remainder_of_binary :: binary()} | :error
  @type parser(success) :: (binary() -> parse_result(success))

  @doc """
  Creates a parser which parses text using all the provided parsers, in order.

  Returns `:error` if any of the underlying parsers returns `:error`.
  """
  @spec sequence(list(parser(term()))) :: parser(list(term()))
  def sequence(parsers) do
    fn text -> sequence(text, parsers) end
  end

  @spec sequence(
          binary(),
          list(parser(term()))
        ) :: parse_result(list(term()))
  defp sequence(text, parsers) when is_binary(text) do
    sequence(text, parsers, [])
  end

  @spec sequence(
          binary(),
          list(parser(term())),
          intermediary_results :: list(term())
        ) :: parse_result(list(term()))
  defp sequence(text, [], results) do
    {Enum.reverse(results), text}
  end

  defp sequence(text, [parser | parsers], results) do
    {parsed, rest} = parser.(text)

    case parsed do
      :error -> :error
      success -> sequence(rest, parsers, [success | results])
    end
  end

  @doc """
  Creates a parser from a list of parsers which attempts to parse the text
  using each parser, in order.

  Returns the first successful parse result.

  Returns `:error` if all of the underlying parsers return `:error`.
  """
  @spec choices(list(parser(term()))) :: parser(term())
  def choices(parsers) do
    fn text -> choices(text, parsers) end
  end

  @spec choices(binary(), list(parser(term()))) :: parse_result(term())
  defp choices(text, []) when is_binary(text), do: :error

  defp choices(text, [parser | parsers]) when is_binary(text) do
    {parsed, rest} = parser.(text)

    case parsed do
      :error -> choices(text, parsers)
      success -> {success, rest}
    end
  end
end
