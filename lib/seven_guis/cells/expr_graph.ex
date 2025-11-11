defmodule SevenGuis.Cells.ExprGraph do
  alias __MODULE__
  alias SevenGuis.Cells.Parser
  alias SevenGuis.Cells.AstNodeTypes, as: AST
  @type coord() :: {integer(), integer()}

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
          subscribers: %{coord() => MapSet.t(coord())}
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
    get_value(expr_graph, coord)
    |> to_charlist()
  end

  def get_cell_info(expr_graph, coord) do
    Map.get(expr_graph.cells, coord, {nil, nil, nil})
  end

  # ----------------------- Subscribers ----------------------

  def get_subscribers(expr_graph, coord) do
    Map.get(expr_graph.subscribers, coord, MapSet.new())
  end

  # ____________________ Update ExprGraph ____________________

  # ------------------- Expressions/Values -------------------
  @spec update_cell(ExprGraph.t(), coord(), charlist()) :: ExprGraph.t()
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
      expr_graph
      |> IO.inspect(label: "subscribers")
      |> unsubscribe(coord, publishers_to_remove)
      |> IO.inspect(label: "subscribers after unsubscribing")
      |> subscribe(coord, publishers_to_add)
      |> IO.inspect(label: "subscribers after subscribing")

    updated_expr_graph = %{updated_expr_graph | subscribers: subscribers}

    # Re-evaluate cells that depend on this cell
    evaluate_recursive(updated_expr_graph, coord)
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

  @spec subscribe(ExprGraph.t(), coord(), Enumerable.t(coord())) :: ExprGraph.t()
  def subscribe(expr_graph, subscriber, publishers) do
    subscribers =
      Enum.reduce(
        publishers,
        expr_graph.subscribers,
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

    %{expr_graph | subscribers: subscribers}
  end

  @spec unsubscribe(ExprGraph.t(), coord(), Enumerable.t(coord())) :: ExprGraph.t()
  def unsubscribe(expr_graph, subscriber, publishers) do
    subscribers =
      Enum.reduce(
        publishers,
        expr_graph.subscribers,
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

    %{expr_graph | subscribers: subscribers}
  end

  # __________________ Evaluating Functions __________________

  # --------------------- Evaluate a Cell --------------------

  @spec evaluate(ExprGraph.t(), AST.ast_node_formula()) :: AST.ast_node_value()
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

  @spec evaluate_recursive(ExprGraph.t(), coord()) :: ExprGraph.t()
  def evaluate_recursive(expr_graph, coord) do
    value = evaluate(expr_graph, coord) |> IO.inspect(label: "value")
    expr_graph = update_value(expr_graph, coord, value)

    Enum.reduce(
      get_subscribers(expr_graph, coord) |> IO.inspect(label: "subs"),
      expr_graph,
      fn subscriber, expr_graph ->
        evaluate_recursive(expr_graph, subscriber)
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
