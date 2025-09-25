defmodule SevenGuis.Counter do
  use WxEx

  @behaviour :wx_object

  def start_link(notebook) do
    :wx_object.start_link(__MODULE__, [notebook], [])
  end

  def init([notebook]) do
    panel = :wxPanel.new(notebook)
    sizer = :wxBoxSizer.new(wxVERTICAL())
    :wxWindow.setSizer(panel, sizer)

    count = 0

    text_id = System.unique_integer([:positive, :monotonic])

    text =
      :wxStaticText.new(
        panel,
        text_id,
        Integer.to_charlist(count)
      )

    :wxSizer.add(
      sizer,
      text,
      # flag: wxEXPAND(),
      proportion: 1,
      border: 5
    )

    button_id = System.unique_integer([:positive, :monotonic])
    button = :wxButton.new(panel, button_id, label: ~c"Count")
    :wxButton.connect(button, :command_button_clicked)

    :wxSizer.add(
      sizer,
      button,
      # flag: wxEXPAND(),
      proportion: 1,
      border: 5
    )

    state = %{panel: panel, count: count, text: text, button: button}
    {panel, state}
  end

  def handle_event({:wx, _, _, _, {:wxCommand, :command_button_clicked, _, _, _}=evt}, state) do
    IO.inspect(evt, label: "Button clicked")
    count = state.count + 1
    :wxStaticText.setLabel(state.text, Integer.to_charlist(count))
    {:noreply, state}
  end
end
