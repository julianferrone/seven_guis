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
      # GUI elements
      canvas: canvas,
      undo: undo,
      redo: redo,
      # Event sourcing
      index: 0,
      commands: []
    }

    {panel, state}
  end

  @circle_radius 20

  def handle_event(
        {:wx, _, _, _, {:wxMouse, :left_down, x, y, _, _, _, _, _, _, _, _, _, _}},
        %{index: index, commands: commands} = state
      ) do
    new_circle = %{
      action: :create,
      index: index,
      x: x,
      y: y,
      r: @circle_radius
    }

    commands = [new_circle | commands]
    state = %{state | commands: commands, index: index + 1}
    {:noreply, state}
  end

  def handle_event(request, state) do
    IO.inspect(request: request, state: state)
    {:noreply, state}
  end

  # _____________________ Event Sourcing _____________________

  def replay(commands) do
    Enum.reduce(
      Enum.reverse(commands),
      %{},
      fn command, state_map -> update(command, state_map) end
    )
  end

  def update(%{action: :create} = command, current) do
    circle = %{
      x: command.x,
      y: command.y,
      r: command.r
    }

    Map.put(
      current,
      command.index,
      circle
    )
  end

  def update(%{action: :resize} = command, current) do
    Map.update!(
      current,
      command.index,
      fn circle -> %{circle | r: command.r} end
    )
  end
end
