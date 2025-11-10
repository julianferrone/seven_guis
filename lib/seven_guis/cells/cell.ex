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
      {:no_function, undefined} -> {:no_function, undefined}
      defined ->
        # Because we use nil as a "no-information at coordinate"
        # we want to just remove the nils from the
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

  def lookup(~c"SUM"), do: &Enum.sum/1
  def lookup(~c"PRODUCT"), do: &Enum.product/1
  def lookup(undefined), do: {:no_function, undefined}
end
