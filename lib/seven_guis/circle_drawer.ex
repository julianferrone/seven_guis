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
    :wxPanel.setBackgroundStyle(canvas, wxBG_STYLE_PAINT())
    :wxPanel.connect(canvas, :left_down)
    :wxPanel.connect(canvas, :right_down)
    :wxPanel.connect(canvas, :motion)
    :wxPanel.connect(canvas, :paint, [:callback])
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
        %{canvas: canvas, index: index, commands: commands, circles: circles} = state
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

    :wxPanel.refresh(canvas)

    {:noreply, state}
  end

  def handle_event(
        {:wx, _, _, _, {:wxMouse, :right_down, x, y, _, _, _, _, _, _, _, _, _, _}},
        %{canvas: canvas, commands: commands, circles: circles} = state
      ) do
    mouse_point = %{x: x, y: y}
    selected_index = selected_circle(mouse_point, circles)

    new_circle = %{
      action: :resize,
      index: selected_index,
      r: 50
    }

    commands = [new_circle | commands]
    circles = update(new_circle, circles)

    state = %{state | commands: commands, circles: circles}

    :wxPanel.refresh(canvas)

    {:noreply, state}
  end

  def handle_event(
        {:wx, _, _, _, {:wxMouse, :motion, x, y, _, _, _, _, _, _, _, _, _, _}},
        %{canvas: canvas, circles: circles} = state
      ) do
    mouse_point = %{x: x, y: y}
    highlighted = selected_circle(mouse_point, circles)
    state = %{state | highlighted: highlighted}

    :wxPanel.refresh(canvas)

    {:noreply, state}
  end

  def handle_event(request, state) do
    IO.inspect(request: request, state: state)
    {:noreply, state}
  end

  def handle_sync_event(
        {:wx, _, _, _, {:wxPaint, :paint}},
        _ref,
        %{canvas: canvas, highlighted: highlighted, circles: circles}
      ) do
    dc = :wxBufferedPaintDC.new(canvas)
    :wxBufferedPaintDC.setBackground(dc, wxWHITE_BRUSH())
    :wxBufferedPaintDC.clear(dc)
    draw(dc, circles, highlighted)
    :wxBufferedPaintDC.destroy(dc)
    :ok
  end

  def handle_sync_event(request, ref, state) do
    IO.inspect(request: request, ref: ref, state: state)
    :ok
  end

  # _____________________ Drawing Circles ____________________

  @spec draw(
          :wxBufferedPaintDC.wxBufferedPaintDC(),
          %{index() => circle()},
          nil | index()
        ) :: :ok
  def draw(
        window,
        circles,
        highlighted
      ) do
    canvas = :wxGraphicsContext.create(window)
    :wxGraphicsContext.setPen(canvas, wxBLACK_PEN())

    # Draw all unselected circles
    :wxGraphicsContext.setBrush(canvas, wxTRANSPARENT_BRUSH())
    unselected_path = :wxGraphicsContext.createPath(canvas)

    for {index, circle} when index != highlighted <- circles do
      # for {_index, circle} when circle.index != highlighted <- circles do
      :wxGraphicsPath.addCircle(unselected_path, circle.x, circle.y, circle.r)
    end

    :wxGraphicsPath.closeSubpath(unselected_path)
    :wxGraphicsContext.drawPath(canvas, unselected_path)
    # cleanup
    :wxGraphicsObject.destroy(unselected_path)

    # Draw selected circle
    if highlighted do
      :wxGraphicsContext.setBrush(canvas, wxLIGHT_GREY_BRUSH())
      selected_path = :wxGraphicsContext.createPath(canvas)

      circle =
        Map.get(circles, highlighted)

      :wxGraphicsPath.addCircle(selected_path, circle.x, circle.y, circle.r)
      :wxGraphicsContext.drawPath(canvas, selected_path)
      # cleanup
      :wxGraphicsObject.destroy(selected_path)
    end

    # Clean up canvas
    :wxGraphicsObject.destroy(canvas)

    :ok
  end

  # __________________ Highlighting Circles __________________

  @type point :: %{x: integer(), y: integer()}
  @type circle :: %{x: integer(), y: integer(), r: float()}
  # Indexing into circles
  @type index :: integer()

  @spec selected_circle(point(), %{index() => circle()}) :: nil | index()
  def selected_circle(point, circles) do
    overlapping_circles =
      Enum.filter(
        circles,
        fn {_index, circle} ->
          is_in_circle(point, circle)
        end
      )

    minimum =
      case Enum.min_by(
             overlapping_circles,
             fn {_index, circle} -> distance(point, circle) end,
             fn -> nil end
           ) do
        {index, _circle} -> index
        nil -> nil
      end

    # |> IO.inspect(label: "minimum")

    minimum
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
