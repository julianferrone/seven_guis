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
  @type ast_node_expr :: {
          :expr,
          ast_node_coord() | ast_node_number() | ast_node_function()
        }

  @type function_name :: String.t()
  @type function_arguments :: [ast_node()]
  @type ast_node_function :: {:function, function_name(), function_arguments()}

  @type ast_node ::
          ast_node_coord()
          | ast_node_number()
          | ast_node_text()
          | ast_node_function()

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
    # |> IO.inspect(label: "sequence finished")
  end

  defp sequence(text, [parser | parsers], results) do
    parsed = parser.(text)
    # |> IO.inspect(label: "sequence")

    case parsed do
      :error -> :error
      # In the case of parsers we want to ignore, don't append to results
      {nil, rest} -> sequence(rest, parsers, results)
      {success, rest} -> sequence(rest, parsers, [success | results])
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
    fn
      text ->
        choices(text, parsers)
        # |> IO.inspect(label: "choices finished")
    end
  end

  @spec choices(binary(), list(parser(term()))) :: parse_result(term())
  defp choices(text, []) when is_binary(text), do: :error

  defp choices(text, [parser | parsers]) when is_binary(text) do
    parsed = parser.(text)
    # |> IO.inspect(label: "choices")

    case parsed do
      :error -> choices(text, parsers)
      {success, rest} -> {success, rest}
    end
  end

  @doc """
  Creates a parser which throws away the result of the underlying parser.

  Returns `nil` if the underlying parser succeeds, returns `:error` if the
  underlying parser returns `:error`.
  """
  def ignore(parser) do
    fn text ->
      result = parser.(text)

      case result do
        :error -> :error
        {_result, rest} -> {nil, rest}
      end
    end
  end

  @doc """
  Creates a parser which errors if the underlying parser doesn't consume
  all input.

  Returns `:error` if the underlying parser
  """
  def parse_all(parser) do
    fn text ->
      result = parser.(text)
      # |> IO.inspect(label: "parse_all")

      case result do
        :error -> :error
        {result, ""} -> {result, ""}
        {_result, _non_empty_string} -> :error
      end
    end
  end

  # -------------------- Parsing Formulae --------------------

  def parse_formula(text) do
    parsed =
      choices([
        parse_all(&parse_float/1),
        parse_all(&parse_expression/1),
        # If we don't parse in a float or an expression, parse as text
        # by pulling the entire string
        parse_all(fn t -> {{:text, t}, ""} end)
      ]).(text)

    case parsed do
      :error -> :error
      {parsed, _rest} -> parsed
    end
  end

  # ------------------- Parsing Expressions ------------------

  def parse_expression(text) do
    expr =
      sequence([
        ignore(parse_char(?=)),
        choices([
          &parse_coord/1,
          &parse_float/1
          # &parse_function/1,
        ])
      ]).(text)

    case expr do
      {[parsed], ""} -> {{:expr, parsed}, ""}
      _ -> :error
    end
  end

  # ................... Parsing Characters ...................

  def parse_char(char) do
    fn text ->
      case String.to_charlist(text) do
        [^char | rest] -> {char, to_string(rest)}
        _ -> :error
      end

      # |> IO.inspect(label: "parse_char")
    end
  end

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
      # |> IO.inspect(label: "parse_coord")
    else
      :error -> :error
    end
  end

  # ..................... Parsing Numbers ....................

  def parse_float(expr) do
    case Float.parse(expr) do
      {float, rest} -> {{:num, float}, rest}
      :error -> :error
    end

    # |> IO.inspect(label: "parse_float")
  end

  # -------------------- Parsing Functions -------------------
end
