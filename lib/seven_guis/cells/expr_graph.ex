defmodule SevenGuis.Cells.ExprGraph do
  alias __MODULE__
  alias SevenGuis.Cells.Parser
  alias SevenGuis.Cells.AstNodeTypes, as: AST
  @type coord() :: {integer(), integer()}

  @type subscriber_map() :: %{coord() => MapSet.t(coord())}

  @type t :: %ExprGraph{
          cells: %{
            coord() => {
              # User input
              charlist(),
              # Parsed expression
              AST.ast_node_formula(),
              # Cached expression value
              AST.ast_node_value()
            }
          },
          subscribers: subscriber_map()
        }
  defstruct [:cells, :subscribers]

  def new() do
    %ExprGraph{
      cells: Map.new(),
      subscribers: Map.new()
    }
  end

  # _____________________ Read ExprGraph _____________________

  # ----------------- Cell Expressions/Values ----------------

  def get_user_input(expr_graph, coord) do
    {user_input, _formula, _value} = get_cell_info(expr_graph, coord)
    user_input
  end

  def get_formula(expr_graph, coord) do
    {_user_input, formula, _value} = get_cell_info(expr_graph, coord)
    formula
  end

  def get_value(expr_graph, coord) do
    {_user_input, _formula, value} = get_cell_info(expr_graph, coord)
    value
  end

  def get_display_value(expr_graph, coord) do
    case get_value(expr_graph, coord) do
      nil -> ~c""
      other -> to_charlist(other)
    end
  end

  def get_cell_info(expr_graph, coord) do
    Map.get(expr_graph.cells, coord, {~c"", nil, nil})
  end

  # ----------------------- Subscribers ----------------------

  def get_subscribers(expr_graph, coord) do
    Map.get(expr_graph.subscribers, coord, MapSet.new())
  end

  # ____________________ Update ExprGraph ____________________

  # ------------------- Expressions/Values -------------------
  @spec update_cell(t(), coord(), charlist()) :: t()
  def update_cell(expr_graph, coord, user_input) do
    # Update cell information
    formula = Parser.parse_formula(user_input)
    value = evaluate(expr_graph, formula)
    cell = {user_input, formula, value}
    cells = Map.put(expr_graph.cells, coord, cell)
    updated_expr_graph = %{expr_graph | cells: cells}

    # Update publishers
    publishers_old = dependencies(get_formula(expr_graph, coord))
    publishers_new = dependencies(formula)
    publishers_to_remove = MapSet.difference(publishers_old, publishers_new)
    publishers_to_add = MapSet.difference(publishers_new, publishers_old)

    subscribers =
      unsubscribe(expr_graph.subscribers, coord, publishers_to_remove)
      |> subscribe(coord, publishers_to_add)

    updated_expr_graph = %{updated_expr_graph | subscribers: subscribers}

    # Re-evaluate cells that depend on this cell
    evaluate_subscribers(updated_expr_graph, coord)
  end

  def update_value(expr_graph, coord, value) do
    cells =
      Map.update!(
        expr_graph.cells,
        coord,
        fn {user_input, formula, _value} -> {user_input, formula, value} end
      )

    %{expr_graph | cells: cells}
  end

  # ----------------------- Subscribers ----------------------

  @spec subscribe(
          subscriber_map(),
          coord(),
          Enumerable.t(coord())
        ) :: subscriber_map()
  def subscribe(subscribers, subscriber, publishers) do
    Enum.reduce(
      publishers,
      subscribers,
      fn publisher, subscribers ->
        Map.update(
          subscribers,
          publisher,
          MapSet.new([subscriber]),
          fn subscribed ->
            MapSet.put(subscribed, subscriber)
          end
        )
      end
    )
  end

  @spec unsubscribe(
          subscriber_map(),
          coord(),
          Enumerable.t(coord())
        ) :: subscriber_map()
  def unsubscribe(subscribers, subscriber, publishers) do
    Enum.reduce(
      publishers,
      subscribers,
      fn publisher, subscribers ->
        Map.update(
          subscribers,
          publisher,
          MapSet.new(),
          fn subscribed ->
            MapSet.delete(subscribed, subscriber)
          end
        )
      end
    )
  end

  # __________________ Evaluating Functions __________________

  # --------------------- Evaluate a Cell --------------------

  @spec evaluate(t(), AST.ast_node_formula()) :: AST.ast_node_value()
  def evaluate(expr_graph, {:expr, {:appl, {:ident, function_name}, args}}) do
    function = lookup(function_name)

    case function do
      {:error, msg} ->
        {:error, msg}

      defined ->
        args =
          args
          # Because we use nil as a "no-information at coordinate"
          # we want to remove nils from the function arguments
          |> Enum.reject(fn arg -> arg == nil end)
          |> Enum.map(fn arg -> evaluate(expr_graph, arg) end)

        try do
          defined.(args)
        rescue
          e ->
            {:error, Exception.message(e)}
        end
    end

    function.(args)
  end

  def evaluate(expr_graph, {:expr, expr}), do: evaluate(expr_graph, expr)
  def evaluate(expr_graph, {:coord, coord}), do: get_value(expr_graph, coord)
  def evaluate(_expr_graph, {_other, other_value}), do: other_value

  # -------------- Evaluate Cell and Subscribers -------------

  @spec evaluate_subscribers(t(), coord()) :: t()
  def evaluate_subscribers(expr_graph, coord) do
    subs = get_subscribers(expr_graph, coord)

    Enum.reduce(
      subs,
      expr_graph,
      fn sub, expr_graph ->
        formula = get_formula(expr_graph, sub)
        value = evaluate(expr_graph, formula)
        expr_graph = update_value(expr_graph, sub, value)
        evaluate_subscribers(expr_graph, sub)
      end
    )
  end

  # ________________ Find Dependencies of Cell _______________

  @spec dependencies(AST.ast_node_formula()) :: MapSet.t(coord())
  def dependencies({:expr, {:appl, _fn_name, args}}) do
    Enum.reduce(
      args,
      MapSet.new(),
      fn arg, deps -> MapSet.union(dependencies(arg), deps) end
    )
  end

  def dependencies({:expr, other}), do: dependencies(other)
  def dependencies({:coord, coord}), do: MapSet.new([coord])
  def dependencies(_other), do: MapSet.new()

  # ________________________ Functions _______________________

  # Binary arithmetic operators
  @spec lookup(any()) :: (any() -> any()) | {:error, <<_::64, _::_*8>>}
  def lookup(~c"PLUS"), do: binary_function(fn a, b -> a + b end)
  def lookup(~c"MINUS"), do: binary_function(fn a, b -> a - b end)
  def lookup(~c"MULT"), do: binary_function(fn a, b -> a * b end)
  def lookup(~c"DIV"), do: binary_function(fn a, b -> a / b end)

  # Arithmetic operators on lists
  def lookup(~c"SUM"), do: &Enum.sum/1
  def lookup(~c"PRODUCT"), do: &Enum.product/1

  def lookup(undefined), do: {:error, "No such function #{undefined}"}

  def binary_function(f) do
    fn args ->
      case args do
        [a, b] ->
          f.(a, b)

        other ->
          arglen = length(other)
          {:error, "Expected 2 arguments, got #{arglen}."}
      end
    end
  end
end
