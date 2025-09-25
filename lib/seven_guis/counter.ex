defmodule SevenGuis.Counter do
  @behaviour :wx_object

  def init(args \\ []) do
    frame = :wxFrame.new()

    button_id = System.unique_integer([:positive, :monotonic])
    button = :wxButton.new(frame, button_id, label: ~c"Count")

    count = 0

    text_id = System.unique_integer([:positive, :monotonic])

    text =
      :wxStaticText.new(
        frame,
        text_id,
        label: Integer.to_charlist(count)
      )

    state = %{frame: frame, count: count, text: text, button: button}
    {frame, state}
  end

  def handle_event({:wx, _, _, _, {:wxCommand, :command_button_clicked, _, _, _}}, state) do
    count = state.count + 1
    :wxStaticText.setLabel(state.text, Integer.to_charlist(count))
    {:noreply, state}
  end
end
