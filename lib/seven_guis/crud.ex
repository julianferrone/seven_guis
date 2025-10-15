defmodule SevenGuis.Crud do
  alias SevenGuis.Id
  use WxEx

  @behaviour :wx_object

  @doc """
  Gap between all grids
  """
  @gap 10

  def start_link(notebook) do
    :wx_object.start_link(__MODULE__, [notebook], [])
  end

  def init([notebook]) do
    # How UI should look:

    #  ┌──────────────────────────────────────────────────────────┐
    #  │                          CRUD                            │
    #  ├──────────────────────────────────────────────────────────┤
    #  │                ┌─────────────┐                           │
    #  │ Filter prefix: │             │                           │
    #  │                └─────────────┘                           │
    #  │ ┌────────────────────────────┐           ┌─────────────┐ │
    #  │ │                            │     Name: │ John        │ │
    #  │ │ Emil, Hans                 │           └─────────────┘ │
    #  │ │ Mustermann, Max            │           ┌─────────────┐ │
    #  │ │ Tisch, Roman               │  Surname: │ Romba       │ │
    #  │ │                            │           └─────────────┘ │
    #  │ │                            │                           │
    #  │ │                            │                           │
    #  │ │                            │                           │
    #  │ │                            │                           │
    #  │ └────────────────────────────┘                           │
    #  │                                                          │
    #  │ ┌────────┐┌────────┐┌────────┐                           │
    #  │ │ Create ││ Update ││ Delete │                           │
    #  │ └────────┘└────────┘└────────┘                           │
    #  └──────────────────────────────────────────────────────────┘

    # Sizer layout:

    # Panel
    # ┌──────────────────────────────────────────┐
    # │Vertical BoxSizer                         │
    # │┌────────────────────────────────────────┐│
    # ││GridBager                               ││
    # ││┌────────────────────┬─────────────────┐││
    # │││Horizontal BoxSizer │                 │││
    # │││┌──────────────────┐│                 │││
    # ││││Label     TextCtrl││                 │││
    # │││└──────────────────┘│                 │││
    # ││├────────────────────┼─────────────────┤││
    # │││ Listbox            │ GridSizer       │││
    # │││                    │ ┌─────┬────────┐│││
    # │││                    │ │Label│TextCtrl││││
    # │││                    │ ├─────┼────────┤│││
    # │││                    │ │Label│TextCtrl││││
    # │││                    │ └─────┴────────┘│││
    # ││└────────────────────┴─────────────────┘││
    # ││Horizontal BoxSizer                     ││
    # ││┌──────────────────────────────────────┐││
    # │││Button Button Button                  │││
    # ││└──────────────────────────────────────┘││
    # │└────────────────────────────────────────┘│
    # └──────────────────────────────────────────┘

    # IDs
    ids =
      Id.generate_ids([
        :prefix_filter,
        :name,
        :surname,
        :create,
        :update,
        :delete
      ])

    # Layout
    panel = :wxPanel.new(notebook)
    main_sizer = :wxBoxSizer.new(wxVERTICAL())
    :wxPanel.setSizer(panel, main_sizer)

    # 1. Main grid sizer
    grid_sizer = :wxGridBagSizer.new(vgap: @gap, hgap: @gap)
    :wxBoxSizer.add(main_sizer, grid_sizer)

    # 1.1. Filter prefix sizer
    filter_prefix_sizer = :wxBoxSizer.new(wxHORIZONTAL())
    :wxGridBagSizer.add(grid_sizer, filter_prefix_sizer, {0, 0})

    # 1.1.1. Filter prefix label
    :wxFlexGridSizer.add(
      filter_prefix_sizer,
      :wxStaticText.new(panel, Id.generate_id(), ~c"Filter prefix:")
    )

    # 1.1.2. Filter prefix text input
    prefix_filter = :wxTextCtrl.new(panel, ids.prefix_filter)

    :wxFlexGridSizer.add(
      filter_prefix_sizer,
      prefix_filter
    )

    :wxTextCtrl.connect(prefix_filter, :command_text_updated)

    # 1.2. List of names
    names = :wxListBox.new(panel, Id.generate_id(), style: wxLB_SINGLE())
    :wxGridBagSizer.add(grid_sizer, names, {1, 0}, flag: wxEXPAND())

    # Initialize list with names
    name_data = initial_names()
    :wxListBox.set(names, name_data)

    # Hook up selection event
    selection_index = 0
    :wxListBox.select(names, selection_index)
    :wxListBox.connect(names, :command_listbox_selected)

    # 1.3. Name inputs sizer
    name_sizer = :wxFlexGridSizer.new(2, 2, @gap, @gap)
    :wxGridBagSizer.add(grid_sizer, name_sizer, {1, 1})

    # 1.3.1. Name label
    :wxFlexGridSizer.add(
      name_sizer,
      :wxStaticText.new(panel, Id.generate_id(), ~c"Name:"),
      flag: wxALIGN_RIGHT()
    )

    # 1.3.2. Given name text input
    given_name = :wxTextCtrl.new(panel, ids.name)

    :wxFlexGridSizer.add(
      name_sizer,
      given_name,
      flag: wxEXPAND()
    )

    # 1.3.3. Surname label
    :wxFlexGridSizer.add(
      name_sizer,
      :wxStaticText.new(panel, Id.generate_id(), ~c"Surname:"),
      flag: wxALIGN_RIGHT()
    )

    # 1.3.4. Surname text input
    surname = :wxTextCtrl.new(panel, ids.surname)

    :wxFlexGridSizer.add(
      name_sizer,
      surname,
      flag: wxEXPAND()
    )

    # 2. Horizontal button box sizer
    button_box_sizer = :wxBoxSizer.new(wxHORIZONTAL())
    :wxBoxSizer.add(main_sizer, button_box_sizer)

    # 2.1. Create Button
    create = :wxButton.new(panel, ids.create, label: ~c"Create")
    :wxBoxSizer.add(button_box_sizer, create)
    :wxButton.connect(create, :command_button_clicked)

    # 2.2. Update Button
    update = :wxButton.new(panel, ids.update, label: ~c"Update")
    :wxBoxSizer.add(button_box_sizer, update)
    :wxButton.connect(update, :command_button_clicked)

    # 2.3. Delete Button
    delete = :wxButton.new(panel, ids.delete, label: ~c"Delete")
    :wxBoxSizer.add(button_box_sizer, delete)
    :wxButton.connect(delete, :command_button_clicked)

    widgets = %{
      # Query
      prefix_filter: prefix_filter,
      # Name text controls
      given_name: given_name,
      surname: surname,
      # List of names
      names: names,
      # Buttons
      create: create,
      update: update,
      delete: delete
    }

    state = %{
      ids: ids,
      widgets: widgets,
      name_data: name_data,
      selection_index: selection_index
    }

    :wxPanel.refresh(panel)
    {panel, state}
  end

  # Handling events
  def handle_event(
        {
          :wx,
          _,
          _,
          _,
          {:wxCommand, :command_listbox_selected, _, index, _}
        },
        state
      ) do
    state = %{state | selection_index: index}
    {:noreply, state}
  end

  def handle_event(
        {
          :wx,
          create_id,
          _,
          _,
          {:wxCommand, :command_button_clicked, _, _, _}
        },
        %{ids: %{create: create_id}} = state
      ) do
    state = append_name(state)
    {:noreply, state}
  end

  def handle_event(
        {
          :wx,
          update_id,
          _,
          _,
          {:wxCommand, :command_button_clicked, _, _, _}
        },
        %{ids: %{update: update_id}} = state
      ) do
    state = update_name(state)
    {:noreply, state}
  end

  def handle_event(
        {
          :wx,
          delete_id,
          _,
          _,
          {:wxCommand, :command_button_clicked, _, _, _}
        },
        %{ids: %{delete: delete_id}} = state
      ) do
    state = delete_name(state)
    {:noreply, state}
  end

  def handle_event(
        {
          :wx,
          prefix_filter_id,
          _,
          _,
          {:wxCommand, :command_text_updated, search_text, _, _}
        },
        %{ids: %{prefix_filter: prefix_filter_id}} = state
      ) do
    update_filtered_names(state.widgets.names, state.name_data, search_text)
    {:noreply, state}
  end

  ## Fallback event handling
  def handle_event(request, state) do
    IO.inspect(request: request, state: state)
    {:noreply, state}
  end

  # Functionality

  @doc """
  Conatenate a name and surname into a single charlist by placing the surname
  first, followed by a comma, followed by the given name.

  # Examples

      iex> arrange_name(~c"John", ~c"Doe")
      ~c"Doe, John"
  """
  @spec arrange_name(charlist(), charlist()) :: charlist()
  def arrange_name(given_name, surname) do
    surname ++ ~c", " ++ given_name
  end

  defp initial_names() do
    [
      ~c"Emil, Hans",
      ~c"Mustermann, Max",
      ~c"Tisch, Roman"
    ]
  end

  @doc """
  Appends a full name to the list of names in the widget.
  """
  def append_name(state) do
    # Get values from widgets
    given_name = :wxTextCtrl.getValue(state.widgets.given_name)
    surname = :wxTextCtrl.getValue(state.widgets.surname)

    # Change data state
    full_name = arrange_name(given_name, surname)
    name_data = state.name_data ++ [full_name]
    state = %{state | name_data: name_data}

    # Update widgets
    :wxListBox.append(state.widgets.names, full_name)
    state
  end

  @doc """
  Updates a name at the selected index of the list of names in the widget.
  """
  def update_name(state) do
    # Get values from widgets
    given_name = :wxTextCtrl.getValue(state.widgets.given_name)
    surname = :wxTextCtrl.getValue(state.widgets.surname)

    index = state.selection_index

    # Change data state
    full_name = arrange_name(given_name, surname)
    name_data = List.replace_at(state.name_data, index, full_name)
    state = %{state | name_data: name_data}

    # Update widgets
    :wxListBox.setString(state.widgets.names, index, full_name)

    state
  end

  @doc """
  Deletes the name at the currently selected index.
  """
  def delete_name(state) do
    index = state.selection_index

    :wxListBox.delete(state.widgets.names, index)
    name_data = List.delete_at(state.name_data, index)
    state = %{state | name_data: name_data}

    state
  end

  @doc """
  Sets the names in the wxListBox `names` to only display the names of
  `name_data` which contain `substring` (case-insensitive).
  """
  def update_filtered_names(names, name_data, substring) do
    filtered = filter_names(name_data, substring)
    :wxListBox.set(names, filtered)
  end

  @doc """
  Returns `true` if `string` contains `search_pattern` (case-insensitive),
  `false` if not.
  """
  def contains(string, search_pattern) do
    string = :string.casefold(string)
    search_pattern = :string.casefold(search_pattern)
    case :string.find(string, search_pattern) do
      :nomatch -> false
      _ -> true
    end
  end

  @doc """
  Filters `name_data` for the charlists which have `substring` in them.
  """
  def filter_names(name_data, substring) do
    Enum.filter(name_data, fn name -> contains(name, substring) end)
  end
end
