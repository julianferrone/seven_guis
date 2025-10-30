defmodule SevenGuis.CircleDrawer do
  alias SevenGuis.Id
  use WxEx
  use Bitwise

  @behaviour :wx_object

  # ____________________ Module Constants ____________________

  # -------------------------- Types -------------------------

  # Circles
  @type point :: %{x: integer(), y: integer()}
  @type circle :: %{x: integer(), y: integer(), r: float()}
  # Indexing into circles
  @type index :: integer()

  # Commands
  @type command_resize :: %{
          action: :resize,
          index: index(),
          from_r: float(),
          to_r: float()
        }

  @type command_create :: %{
          action: :create,
          index: index(),
          x: integer(),
          y: integer(),
          r: float()
        }

  @type command :: command_resize() | command_create()
  @type commands :: %{done: [command()], undone: [command()]}

  # ------------------------ Graphics ------------------------

  @border 10

  # ------------------- Circle Constraints -------------------

  @radius_min 10
  @radius_default 20
  @radius_max 50

  # __________________ Widget Initialisation _________________

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

    # 3. Create resize dialog for circles
    resize_dialog = :wxDialog.new(panel, Id.generate_id(), ~c"Resize Circle")
    :wxDialog.connect(resize_dialog, :close_window)

    dialog_sizer = :wxBoxSizer.new(wxVERTICAL())
    :wxDialog.setSizer(resize_dialog, dialog_sizer)

    :wxBoxSizer.add(
      dialog_sizer,
      :wxStaticText.new(resize_dialog, Id.generate_id(), ~c"Adjust Diameter",
        style: wxALIGN_CENTER() ||| wxST_NO_AUTORESIZE()
      ),
      flag: wxEXPAND() ||| wxALL(),
      border: @border
    )

    radius_slider =
      :wxSlider.new(
        resize_dialog,
        Id.generate_id(),
        @radius_default,
        @radius_min,
        @radius_max
      )

    # :wxSlider.connect(radius_slider, :scroll_changed)
    :wxSlider.connect(radius_slider, :command_slider_updated)

    :wxBoxSizer.add(
      dialog_sizer,
      radius_slider,
      flag: wxEXPAND(),
      border: @border
    )

    # Force layout
    :wxSizer.layout(main_sizer)

    state = %{
      panel: panel,
      # GUI elements
      canvas: canvas,
      undo: undo,
      redo: redo,
      resize_dialog: resize_dialog,
      radius_slider: radius_slider,
      # Event sourcing
      index: 0,
      commands: empty_commands(),
      # Circle map
      circles: %{},
      # is user highlighting a circle? nil if not, index number if yes
      highlighted: nil,
      # if user is resizing a circle, this was the original circle radius
      highlighted_prev_radius: nil
    }

    {panel, state}
  end

  # ___________________ Handling GUI Events __________________

  # ------------------- Asynchronous Events ------------------

  def handle_event(
        {:wx, _, _, _, {:wxMouse, :left_down, x, y, _, _, _, _, _, _, _, _, _, _}},
        %{canvas: canvas, index: index, commands: commands, circles: circles} = state
      ) do
    create_circle = %{
      action: :create,
      index: index,
      x: x,
      y: y,
      r: @radius_default
    }

    commands = add_command(commands, create_circle)

    index = index + 1
    circles = update(circles, create_circle)

    state = %{state | commands: commands, index: index, circles: circles}

    :wxPanel.refresh(canvas)

    {:noreply, state}
  end

  def handle_event(
        {:wx, _, _, _, {:wxMouse, :right_down, x, y, _, _, _, _, _, _, _, _, _, _}},
        %{
          resize_dialog: resize_dialog,
          radius_slider: radius_slider,
          canvas: canvas,
          circles: circles
        } = state
      ) do
    mouse_point = %{x: x, y: y}

    highlighted =
      selected_circle(mouse_point, circles)

    state = %{state | highlighted: highlighted}

    state =
      case highlighted do
        nil ->
          state

        _selected_index ->
          circle = Map.get(circles, highlighted)
          :wxSlider.setValue(radius_slider, circle.r)
          :wxDialog.show(resize_dialog)
          %{state | highlighted_prev_radius: circle.r}
      end

    :wxPanel.refresh(canvas)

    {:noreply, state}
  end

  def handle_event(
        {:wx, _, _, _, {:wxMouse, :motion, x, y, _, _, _, _, _, _, _, _, _, _}},
        %{canvas: canvas, circles: circles, resize_dialog: resize_dialog} = state
      ) do
    state =
      if not :wxDialog.isShown(resize_dialog) do
        mouse_point = %{x: x, y: y}
        highlighted = selected_circle(mouse_point, circles)
        state = %{state | highlighted: highlighted}
        :wxPanel.refresh(canvas)
        state
      else
        state
      end

    {:noreply, state}
  end

  # Redraw canvas when dialog slider is moved
  def handle_event(
        {:wx, _, _, _, {:wxCommand, :command_slider_updated, _, radius, _}},
        %{canvas: canvas, highlighted: highlighted, circles: circles} = state
      ) do
    new_circle = %{
      action: :resize,
      index: highlighted,
      to_r: radius
    }

    circles = update(circles, new_circle)

    state = %{state | circles: circles}

    :wxPanel.refresh(canvas)

    {:noreply, state}
  end

  # Actually update circles when dialog is closed
  def handle_event(
        {:wx, _, resize_dialog, _, {:wxClose, :close_window}},
        %{
          resize_dialog: resize_dialog,
          commands: commands,
          circles: circles,
          highlighted: highlighted,
          highlighted_prev_radius: highlighted_prev_radius
        } = state
      ) do
    circle = Map.get(circles, highlighted)

    resize = %{
      action: :resize,
      index: highlighted,
      from_r: highlighted_prev_radius,
      to_r: circle.r
    }

    commands = add_command(commands, resize)
    circles = update(circles, resize)

    state = %{state | commands: commands, circles: circles}
    :wxDialog.show(resize_dialog, show: false)
    {:noreply, state}
  end

  def handle_event(
        {:wx, _, undo, _, {:wxCommand, :command_button_clicked, _, _, _}},
        %{canvas: canvas, undo: undo, commands: commands, circles: circles} = state
      ) do
    {commands, circles} = undo(commands, circles)
    state = %{state | commands: commands, circles: circles}
    :wxPanel.refresh(canvas)
    {:noreply, state}
  end

  def handle_event(
        {:wx, _, redo, _, {:wxCommand, :command_button_clicked, _, _, _}},
        %{canvas: canvas, redo: redo, commands: commands, circles: circles} = state
      ) do
    {commands, circles} = redo(commands, circles)
    state = %{state | commands: commands, circles: circles}
    :wxPanel.refresh(canvas)
    {:noreply, state}
  end

  def handle_event(request, state) do
    IO.inspect(request: request, state: state)
    {:noreply, state}
  end

  # ------------------- Synchronous Events -------------------

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
  end

  def handle_sync_event(request, ref, state) do
    IO.inspect(request: request, ref: ref, state: state)
    :ok
  end

  # _____________________ Drawing Circles ____________________

  @doc """
  Draws circles on a WX canvas, optionally highlighting one.

  ## Description

  This function renders a collection of circles on a WX `BufferedPaintDC`.
  All circles are drawn with a black outline. The currently `highlighted`
  circle, if provided, is filled with light grey, while all other circles are
  drawn transparent.

  The function uses `:wxGraphicsContext` for vector-style drawing and cleans up
  all graphics objects after drawing.

  ## Parameters

    * `dc` — a `:wxBufferedPaintDC.wxBufferedPaintDC()` representing the
      drawing surface.
    * `circles` — a map of circles indexed by `index()`, where each circle
      has fields:
        * `:x` — x-coordinate of the circle center.
        * `:y` — y-coordinate of the circle center.
        * `:r` — radius of the circle.
    * `highlighted` — an optional `index()` of the circle to highlight. If
      `nil`, no circle is highlighted.

  ## Returns

    * `:ok`

  """
  @spec draw(
          :wxBufferedPaintDC.wxBufferedPaintDC(),
          %{index() => circle()},
          nil | index()
        ) :: :ok
  def draw(
        dc,
        circles,
        highlighted
      ) do
    canvas = :wxGraphicsContext.create(dc)
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

    # Clean up graphics
    :wxGraphicsObject.destroy(canvas)

    :ok
  end

  # __________________ Highlighting  __________________

  @doc """
  Determines which circle (if any) a given point lies within, returning the index
  of the closest overlapping circle.

  ## Description

  This function checks a collection of circles and identifies which ones contain
  the given point.

  If multiple circles overlap the point, it returns the index of the circle
  center is **closest** to the point.

  If no circle contains the point, it returns `nil`.

  ## Parameters

  * `point` — a map or struct representing a point, expected to have numeric
    fields `:x` and `:y`.
  * `circles` — a map where each key is an `index()` (identifier) and each value
    is a `circle()` (a map or struct with fields `:x`, `:y`, and `:r`).

  ## Returns

  * The `index()` of the closest circle that contains the point, or
  * `nil` if the point lies outside all circles.
  """
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

    minimum
  end

  @doc """
  Determines whether a point lies inside (or on the edge of) a given circle.

  ## Parameters

    * `point` — a map or struct representing a point, expected to have numeric
        fields `:x` and `:y`.
    * `circle` — a map or struct representing a circle, expected to have numeric
        fields `:x`, `:y`, and `:r`, where `:x` and `:y` define the circle’s
        center, and `:r` is its radius.

  ## Returns

    * `true` if the point lies within or exactly on the circle’s boundary.
    * `false` otherwise.

  ## Examples

      iex> is_in_circle(%{x: 1, y: 1}, %{x: 0, y: 0, r: 2})
      true

      iex> is_in_circle(%{x: 3, y: 3}, %{x: 0, y: 0, r: 2})
      false

  """
  @spec is_in_circle(point(), circle()) :: boolean()
  defp is_in_circle(point, circle) do
    # Calculates the distance between the point and the circle origin
    distance(point, circle) <= circle.r
  end

  @doc """
  Calculates the Euclidean distance between two points.

  ## Parameters

    * `point_a` — a map or struct representing the first point, expected to
      have numeric fields `:x` and `:y`.
    * `point_b` — a map or struct representing the second point, expected to
      have numeric fields `:x` and `:y`.

  ## Returns

    * A `float()` representing the straight-line (Euclidean) distance between
      `point_a` and `point_b`.
  """
  @spec distance(point(), point()) :: float()
  defp distance(point_a, point_b) do
    ((point_a.x - point_b.x) ** 2 + (point_a.y - point_b.y) ** 2) ** 0.5
  end

  # _____________________ Event Sourcing _____________________

  @doc """
  Redoes the most recently undone command, updating both the command history
  and the circles.

  ## Description

  Performs a **redo** operation by:

    1. Moving the most recently undone command from the `:undone` list back to
      the `:done` list.
    2. Reapplying that command to the circles.

  If there are no undone commands, the circles and command history remain
  unchanged.

  ## Parameters

    * `commands` — a `commands()` map containing:
        * `:done` — the list of executed commands.
        * `:undone` — the list of undone commands.
    * `circles` — a map of circles indexed by `index()`.

  ## Returns

    * A tuple `{commands(), circles()}`:
        * The updated command history with the last undone command redone.
        * The updated circles map reflecting the applied command.
  """
  @spec redo(commands(), %{index() => circle()}) :: {commands(), %{index() => circle()}}
  def redo(commands, circles) do
    commands = forward(commands)
    circles = update(circles, focus(commands))

    {commands, circles}
  end

  @doc """
  Undoes the most recent command, updating both the command history and the
  circles.

  ## Description

  Performs an **undo** operation by:

    1. Reverting the effect of the most recently executed command on the
      circles.
    2. Moving that command from the `:done` list to the `:undone` list in the
      command history.

  If there are no executed commands, the circles and command history remain
  unchanged.

  ## Parameters

    * `commands` — a `commands()` map containing:
        * `:done` — the list of executed commands.
        * `:undone` — the list of undone commands.
    * `circles` — a map of circles indexed by `index()`.

  ## Returns

    * A tuple `{commands(), circles()}`:
        * The updated command history with the last command undone.
        * The updated circles map reflecting the reverted command.
  """
  @spec undo(commands(), %{index() => circle()}) :: {commands(), %{index() => circle()}}
  def undo(commands, circles) do
    circles = revert(circles, focus(commands))
    commands = backward(commands)

    {commands, circles}
  end

  # ----------------- List Zipper Operations -----------------

  @doc """
  Creates an empty command history.

  ## Description

  Returns a `commands()` map with no executed or undone commands.
  This can be used to initialize an undo/redo system.

  ## Parameters

    * None

  ## Returns

    * A `commands()` map where:
        * `:done` is an empty list of executed commands.
        * `:undone` is an empty list of undone commands.

  ## Examples

      iex> empty_commands()
      %{done: [], undone: []}
  """
  @spec empty_commands() :: commands()
  def empty_commands() do
    %{
      done: [],
      undone: []
    }
  end

  @doc """
  Returns the most recently executed command from the history.

  ## Description

  The `focus/1` function retrieves the command at the "focus" of the command
  history — that is, the most recently executed command in the `:done` list.

  If no commands have been executed (`:done` is empty), it returns `nil`.

  ## Parameters

  * `commands` — a `commands()` map containing:
    * `:done` — the list of executed commands.
    * `:undone` — the list of undone commands.

  ## Returns

  * The most recent `command()` from the `:done` list, or `nil` if there are
  no executed commands.
  """
  @spec focus(commands()) :: command() | nil
  def focus(%{done: []}), do: nil
  def focus(%{done: [focal_point | _rest]}), do: focal_point

  @doc """
  Adds a new command to the command history, clearing the redo stack.

  ## Description

  Records a new command by prepending it to the `:done` list and resetting
  the `:undone` list. This ensures that any previously undone commands
  cannot be redone after a new command is added.

  ## Parameters

    * `commands` — a `commands()` map containing:
        * `:done` — the list of executed commands.
        * `:undone` — the list of undone commands.
    * `command` — a `command()` map representing the new action to record.

  ## Returns

    * A new `commands()` map with the new command added to `:done` and
      `:undone` cleared.
  """
  @spec add_command(commands(), command()) :: commands()
  def add_command(%{done: done}, command) do
    %{
      done: [command | done],
      undone: []
    }
  end

  @doc """
  Moves one command forward in the command history.

  ## Description

  Performs a **redo** operation by transferring the most recently undone
  command from the `:undone` list back to the `:done` list.

  If there are no undone commands (i.e. the `:undone` list is empty),
  the function returns the `commands` map unchanged.

  ## Parameters

  * `commands` — a `commands()` map containing:
    * `:done` — the list of commands that have been executed.
    * `:undone` — the list of commands that have been undone and may be redone.

  ## Returns

  * A new `commands()` map with one command moved from `:undone` to `:done`,
  or the unchanged map if there are no commands to redo.
  """

  @spec forward(commands()) :: commands()
  def forward(%{undone: []} = commands) do
    commands
  end

  def forward(%{done: done, undone: [next | rest]}) do
    %{
      done: [next | done],
      undone: rest
    }
  end

  @doc """
  Moves one command backward in the command history.

  ## Description

  Performs an **undo** operation by transferring the most recently executed
  command from the `:done` list to the `:undone` list.

  If there are no executed commands (i.e. the `:done` list is empty),
  the function returns the `commands` map unchanged.

  ## Parameters

  * `commands` — a `commands()` map containing:
    * `:done` — the list of commands that have been executed.
    * `:undone` — the list of commands that have been undone.

  ## Returns

  * A new `commands()` map with one command moved from `:done` to `:undone`,
    or the unchanged map if there are no commands to undo.
  """
  @spec backward(commands()) :: commands()
  def backward(%{done: []} = commands) do
    commands
  end

  def backward(%{done: [last | done], undone: undone}) do
    %{
      done: done,
      undone: [last | undone]
    }
  end

  # -------------------- Do Circle Changes -------------------

  @doc """
  Applies a circle-related command to update the collection of circles.

  ## Description

  This function performs an update operation on a map of circles based on
  the provided `command`. Supported actions are:

  * `:create` — adds a new circle at the given index using its position (`:x`,
    `:y`) and radius (`:r`).
  * `:resize` — updates the radius of an existing circle to a new value
    (`:to_r`).

  ## Parameters

  * `circles` — a map where each key is an `index()` (identifier) and each
    value is a `circle()`(a map or struct with fields `:x`, `:y`, and `:r`).
  * `command` — a `command()` map describing the action to apply.
    Must include:
      * `:action` — either `:create` or `:resize`.
      * `:index` — the target circle’s identifier.
      * For `:create`: `:x`, `:y`, and `:r`.
      * For `:resize`: `:to_r` — the new radius.

  ## Returns

  * A new map of circles with the command applied.
  """
  @spec update(%{index() => circle()}, command()) :: %{index() => circle()}
  def update(circles, %{action: :create} = command) do
    circle = Map.take(command, [:x, :y, :r])
    Map.put(circles, command.index, circle)
  end

  def update(circles, %{action: :resize} = command) do
    update_circle_radius(circles, command.index, command.to_r)
  end

  # ------------------- Undo Circle Changes ------------------

  @doc """
  Reverts a circle-related action, restoring the previous state of the
  collection.

  ## Description

  This function undoes an operation on a collection of circles based on the
  provided `command`. Supported actions are:

  * `:create` — removes the newly created circle.
  * `:resize` — restores the circle’s previous radius (`:from_r`).

  ## Parameters

  * `circles` — a map where each key is an `index()` (identifier) and each
    value is a `circle()` (a map or struct with fields `:x`, `:y`, and `:r`).
  * `command` — a `command()` map describing the action to revert.
    Must include:
      * `:action` — either `:create` or `:resize`.
      * `:index` — the target circle’s identifier.
      * For `:resize`, also `:from_r` — the previous radius.

  ## Returns

  * A new map of circles with the action reverted.
  """
  @spec revert(%{index() => circle()}, command()) :: %{index() => circle()}
  def revert(circles, %{action: :create} = command) do
    Map.delete(circles, command.index)
  end

  def revert(circles, %{action: :resize} = command) do
    update_circle_radius(circles, command.index, command.from_r)
  end

  # --------------------- Change Helpers ---------------------

  @doc """
  Updates the radius of a specific circle in a collection of circles.

  ## Description

  Given a map of circles indexed by an identifier, this function updates
  the radius (`:r` field) of the circle at the specified `index`.

  It raises a `KeyError` if no circle exists at the given index, since it uses
  `Map.update!/3` internally.

  ## Parameters

  * `circles` — a map where each key is an `index()` (identifier) and each value is a `circle()`
    (a map or struct with fields `:x`, `:y`, and `:r`).
  * `index` — the key identifying which circle to update.
  * `radius` — the new radius value, as a `float()`.

  ## Returns

  * A new map of circles with the updated radius for the specified circle.
  """
  @spec update_circle_radius(%{index() => circle()}, index(), float()) :: %{index() => circle()}
  def update_circle_radius(circles, index, radius) do
    Map.update!(
      circles,
      index,
      fn circle -> Map.put(circle, :r, radius) end
    )
  end
end
