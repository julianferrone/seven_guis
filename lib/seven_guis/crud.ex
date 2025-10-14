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

    # 1.2. List of names
    names = :wxListCtrl.new(panel)
    :wxGridBagSizer.add(grid_sizer, names, {1, 0}, flag: wxEXPAND())

    # 1.3. Name inputs sizer
    name_sizer = :wxFlexGridSizer.new(2, 2, @gap, @gap)
    :wxGridBagSizer.add(grid_sizer, name_sizer, {1, 1})

    # 1.3.1. Name label
    :wxFlexGridSizer.add(
      name_sizer,
      :wxStaticText.new(panel, Id.generate_id(), ~c"Name:"),
      flag: wxALIGN_RIGHT()
    )

    # 1.3.2. Name text input
    name = :wxTextCtrl.new(panel, ids.name)

    :wxFlexGridSizer.add(
      name_sizer,
      name,
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

    # 2.2. Update Button
    update = :wxButton.new(panel, ids.update, label: ~c"Update")
    :wxBoxSizer.add(button_box_sizer, update)

    # 2.3. Delete Button
    delete = :wxButton.new(panel, ids.delete, label: ~c"Delete")
    :wxBoxSizer.add(button_box_sizer, delete)

    widgets = %{
      prefix_filter: prefix_filter,
      name: name,
      surname: surname,
      create: create,
      update: update,
      delete: delete
    }

    state = %{
      ids: ids,
      widgets: widgets,
    }

    :wxPanel.refresh(panel)
    {panel, state}
  end
end
