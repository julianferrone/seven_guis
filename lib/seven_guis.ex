defmodule SevenGuis do
  use WxEx

  # https://gist.github.com/rlipscombe/5f400451706efde62acbbd80700a6b7c
  @behaviour :wx_object

  @title "Seven GUIs"
  @size {600, 600}

  def start_link() do
    :wx_object.start_link(__MODULE__, [], [])
  end

  def init(args \\ []) do
    wx = :wx.new()
    frame = :wxFrame.new(wx, -1, @title, size: @size)
    :wxFrame.connect(frame, :size)
    :wxFrame.connect(frame, :close_window)

    main_panel = :wxPanel.new(frame, [])
    :wxPanel.connect(main_panel, :paint, [:callback])

    main_sizer = :wxBoxSizer.new(wxVERTICAL())

    notebook_id = System.unique_integer([:positive, :monotonic])
    notebook = :wxNotebook.new(main_panel, notebook_id, style: wxNB_TOP())

    counter_panel = SevenGuis.Counter.start_link(notebook)
    :wxNotebook.addPage(notebook, counter_panel, "Counter")

    temperature_panel = SevenGuis.Temperature.start_link(notebook)
    :wxNotebook.addPage(notebook, temperature_panel, "Temperature Converter")

    flights_panel = :wxPanel.new(notebook)
    :wxNotebook.addPage(notebook, flights_panel, "Flight Booker")

    timer_panel = :wxPanel.new(notebook)
    :wxNotebook.addPage(notebook, timer_panel, "Timer")

    crud_panel = :wxPanel.new(notebook)
    :wxNotebook.addPage(notebook, crud_panel, "CRUD")

    circle_drawer_panel = :wxPanel.new(notebook)
    :wxNotebook.addPage(notebook, circle_drawer_panel, "Circle Drawer")

    cells_panel = :wxPanel.new(notebook)
    :wxNotebook.addPage(notebook, cells_panel, "Cells")

    :wxSizer.add(main_sizer, notebook, flag: wxEXPAND(), proportion: 1)
    :wxPanel.setSizer(main_panel, main_sizer)

    :wxWindow.refresh(main_panel)
    :wxFrame.show(frame)

    state = %{main_panel: main_panel, frame: frame}
    {frame, state}
  end

  def handle_event({:wx, _, _, _, {:wxSize, :size, size, _}}, state = %{main_panel: main_panel}) do
    :wxPanel.setSize(main_panel, size)
    {:noreply, state}
  end

  def handle_event({:wx, _, _, _, {:wxClose, :close_window}}, state) do
    {:stop, :normal, state}
  end

  def handle_event({:wx, _, ref, _, {:wxCommand, :command_button_clicked, _, _, _}}, state) do
    # :wxButton.destroy(ref)
    text_line = :wxTextCtrl.getLineText(state.text, 0)
    :wxButton.setLabel(state.button, text_line)
    {:noreply, state}
  end

  def handle_event({:wx, _, _, _, evt}, state) do
    IO.inspect(evt, label: "Event")
    {:noreply, state}
  end

  def handle_sync_event({:wx, _, _, _, {:wxPaint, :paint}}, _, state = %{main_panel: main_panel}) do
    brush = :wxBrush.new()
    :wxBrush.setColour(brush, {255, 255, 255, 255})

    dc = :wxPaintDC.new(main_panel)
    :wxDC.setBackground(dc, brush)
    :wxDC.clear(dc)
    :wxPaintDC.destroy(dc)
    :ok
  end
end
