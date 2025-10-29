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
      commands: [],
      # Circle map
      circles: %{},
      # is user highlighting a circle? nil if not, index number if yes
      highlighted: nil
    }

    {panel, state}
  end

  @circle_radius 20

  def handle_event(
        {:wx, _, _, _, {:wxMouse, :left_down, x, y, _, _, _, _, _, _, _, _, _, _}},
        %{index: index, commands: commands, circles: circles} = state
      ) do
    new_circle = %{
      action: :create,
      index: index,
      x: x,
      y: y,
      r: @circle_radius
    }

    commands = [new_circle | commands]
    index = index + 1
    circles = update(new_circle, circles)

    state = %{state | commands: commands, index: index, circles: circles}
    {:noreply, state}
  end

  def handle_event(
        {:wx, _, _, _, {:wxMouse, :motion, x, y, _, _, _, _, _, _, _, _, _, _}},
        %{circles: circles} = state
      ) do
    mouse_point = %{x: x, y: y}
    highlighted = selected_circle(mouse_point, circles)
    state = %{state | highlighted: highlighted}
    {:noreply, state}
  end

  def handle_event(request, state) do
    IO.inspect(request: request, state: state)
    {:noreply, state}
  end

  # __________________ Highlighting Circles __________________

  @type point :: %{x: integer(), y: integer()}
  @type circle :: %{x: integer(), y: integer(), r: float()}
  # Indexing into circles
  @type index :: integer()

  @spec selected_circle(point(), %{index() => circle()}) :: nil | circle()
  def selected_circle(point, circles) do
    overlapping_circles =
      Enum.filter(
        circles,
        fn {index, circle} -> {index, is_in_circle(point, circle)} end
      )

    case Enum.min_by(
      overlapping_circles,
      fn {_index, circle} -> distance(point, circle) end,
      fn -> nil end
    ) do
      {index, _circle} -> index
      nil -> nil
    end
  end

  @spec is_in_circle(point(), circle()) :: boolean()
  defp is_in_circle(point, circle) do
    # Calculates the distance between the point and the circle origin
    distance(point, circle) <= circle.r
  end

  @spec distance(point(), point()) :: float()
  defp distance(point_a, point_b) do
    ((point_a.x - point_b.x) ** 2 + (point_a.y - point_b.y) ** 2) ** 0.5
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
