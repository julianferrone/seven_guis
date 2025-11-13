defmodule SevenGuis.WxRecord do
  @moduledoc """
  Provides WX records for pattern matching.

  ## Examples

      iex> def handle_event(WxRecord.wx(event: event)=request, state) do
      ...>   IO.inspect(request: request, state: state)
      ...>   state = do_something(event)
      ...>   {:noreply, state}
      ...> end
  """
  require Record

  Record.extract_all(from_lib: "wx/include/wx.hrl")
  |> Enum.each(fn {name, fields} -> Record.defrecord(name, fields) end)
end
