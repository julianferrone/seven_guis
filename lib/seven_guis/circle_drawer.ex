defmodule SevenGuis.CircleDrawer do
  use WxEx

  @behaviour :wx_object

  def start_link(notebook) do
    :wx_object.start_link(__MODULE__, [notebook], [])
  end

  def init([notebook]) do
    panel = :wxPanel.new(notebook)
    # main_sizer = :wxStaticBoxSizer.new(wxVERTICAL(), panel, label: ~c"Circle Drawer")
    main_sizer = :wxBoxSizer.new(wxVERTICAL())
    :wxPanel.setSizer(panel, main_sizer)

    # 1. Create buttons for undo/redo
    button_sizer = :wxBoxSizer.new(wxHORIZONTAL())
    :wxBoxSizer.add(main_sizer, button_sizer)

    # 1.1. Undo button
    undo = :wxButton.new(panel, wxID_UNDO())
    :wxButton.connect(undo, :command_button_clicked)
    :wxBoxSizer.add(button_sizer, undo)

    # 1.2. Redo button
    redo = :wxButton.new(panel, wxID_REDO())
    :wxButton.connect(redo, :command_button_clicked)
    :wxBoxSizer.add(button_sizer, redo)

    # 2. Create window to paint on and make it repaint the whole window on resize
    canvas = :wxPanel.new(panel, style: wxFULL_REPAINT_ON_RESIZE())
    :wxPanel.connect(canvas, :left_down)
    :wxPanel.connect(canvas, :motion)
    :wxSizer.add(main_sizer, canvas, flag: wxEXPAND(), proportion: 1)

    # Force layout
    :wxSizer.layout(main_sizer)

    state = %{
      canvas: canvas,
      undo: undo,
      redo: redo
    }

    {panel, state}
  end

  def handle_event(request, state) do
    IO.inspect(request: request, state: state)
    {:noreply, state}
  end
end
