defmodule SevenGuis.Cells.Cell do
  use GenServer

  defstruct [:subscribers, :formula]

  alias SevenGuis.Cells.AstNodeTypes, as: AST
  alias __MODULE__, as: State
  alias SevenGuis.Cells.Registry, as: CellRegistry

  @spec start_link(AST.ast_node_formula(), {integer(), integer()}) :: GenServer.on_start()
  def start_link(formula, coord) do
    GenServer.start_link(__MODULE__, formula, name: via_tuple(coord))
  end

  def init(formula) do
    state = %State{
      subscribers: MapSet.new(),
      formula: formula
    }

    {:ok, state}
  end

  def handle_call(:subscribe, {pid_from, _tag}, %State{subscribers: subscribers} = state) do
    subscribers = MapSet.put(subscribers, pid_from)
    state = %{state | subscribers: subscribers}
    {:reply, :ok, state}
  end

  def handle_call(:unsubscribe, {pid_from, _tag}, %State{subscribers: subscribers} = state) do
    subscribers = MapSet.delete(subscribers, pid_from)
    state = %{state | subscribers: subscribers}
    {:reply, :ok, state}
  end

  def handle_call(:get_value, _from, state) do
    value = evaluate(state.formula)
    {:reply, value, state}
  end

  defp via_tuple(coord) do
    CellRegistry.via_tuple(coord)
  end

  # ____________________ Evaluate Formulas ___________________

  @spec evaluate(AST.ast_node_formula()) ::
          AST.ast_node_integer()
          | AST.ast_node_text()
          | AST.ast_node_float()

  def evaluate({:expr, {:appl, {:ident, function_name}, args}}) do
    function = lookup(function_name)

    case function do
      {:no_function, undefined} ->
        {:no_function, undefined}

      defined ->
        # Because we use nil as a "no-information at coordinate"
        # we want to remove nils from the function arguments
        args = Enum.reject(args, fn x -> x == nil end)
        defined.(args)
    end

    function.(args)
  end

  def evaluate({:coord, coord}) do
    try do
      GenServer.call(via_tuple(coord), :get_value)
    catch
      :exit, _ -> nil
    end
  end

  def evaluate({:expr, expr}), do: evaluate(expr)
  def evaluate({_other, other_value}), do: other_value

  # Binary arithmetic operators
  def lookup(~c"PLUS"), do: binary_function(fn a, b -> a + b end)
  def lookup(~c"MINUS"), do: binary_function(fn a, b -> a - b end)
  def lookup(~c"MULT"), do: binary_function(fn a, b -> a * b end)
  def lookup(~c"DIV"), do: binary_function(fn a, b -> a / b end)

  # Arithmetic operators on lists
  def lookup(~c"SUM"), do: &Enum.sum/1
  def lookup(~c"PRODUCT"), do: &Enum.product/1

  def lookup(undefined), do: {:no_function, undefined}

  def binary_function(f) do
    fn args ->
      case args do
        [a, b] ->
          f.(a, b)

        other ->
          arglen = length(other)
          {:wrong_arglen, "Expected 2 arguments, got #{arglen}."}
      end
    end
  end
end
