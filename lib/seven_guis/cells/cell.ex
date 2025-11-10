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

  defp via_tuple(coord) do
    CellRegistry.via_tuple(coord)
  end
end
