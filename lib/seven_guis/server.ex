defmodule SevenGuis.Server do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, [])
  end

  @impl GenServer
  def init(_) do
    {:wx_ref, _, _, pid} = SevenGuis.start_link()
    ref = Process.monitor(pid)

    {:ok, {ref, pid}}
  end

  @impl GenServer
  def handle_info({:DOWN, _, _, _, _}, _state) do
    System.stop(0)
    {:stop, :ignore, nil}
  end
end
