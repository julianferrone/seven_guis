defmodule SevenGuis.Cells.Cell do
  use GenServer

  defstruct [:subscribers, :formula]

  alias __MODULE__, as: State

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

  # def handle_call(:get_value, _from, state) do
  #   evaluate formula here
  #   arguments = GenServer.call()
  #   value = evaluate
  #   {:reply, value, state}
  # end
end
