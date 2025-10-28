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

    # Create window to paint on and make it repaint the whole window on resize
    canvas = :wxPanel.new(panel, style: wxFULL_REPAINT_ON_RESIZE())
    :wxSizer.add(main_sizer, canvas, flag: wxEXPAND(), proportion: 1)
    :wxPanel.connect(canvas, :left_down)
    :wxPanel.connect(canvas, :motion)

    # Force layout
    :wxSizer.layout(main_sizer)

    state = %{canvas: canvas}
    {panel, state}
  end

  def handle_event(request, state) do
    IO.inspect(request: request, state: state)
    {:noreply, state}
  end
end
