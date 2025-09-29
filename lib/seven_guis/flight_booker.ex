defmodule SevenGuis.FlightBooker do
  use WxEx

  @behaviour :wx_object

  @white {255, 255, 255}
  @error_red {255, 150, 150}
  @invalid_grey {200, 200, 200}

  @one_way_flight ~c"one-way flight"
  @return_flight ~c"return flight"

  def start_link(notebook) do
    :wx_object.start_link(__MODULE__, [notebook], [])
  end

  def init([notebook]) do
    panel = :wxPanel.new(notebook)
    sizer = :wxBoxSizer.new(wxVERTICAL())
    :wxWindow.setSizer(panel, sizer)

    # Checkbox
    flight_choice_id = System.unique_integer([:positive, :monotonic])

    flight_choice =
      :wxChoice.new(
        panel,
        flight_choice_id,
        choices: [@one_way_flight, @return_flight]
      )

    :wxChoice.connect(flight_choice, :command_choice_selected)

    :wxSizer.add(
      sizer,
      flight_choice,
      # flag: wxEXPAND(),
      proportion: 0,
      border: 5
    )

    # Start date
    start_date_id = System.unique_integer([:positive, :monotonic])
    start_date = :wxTextCtrl.new(panel, start_date_id)

    :wxSizer.add(
      sizer,
      start_date,
      # flag: wxEXPAND(),
      proportion: 0,
      border: 5
    )

    # Return date
    return_date_id = System.unique_integer([:positive, :monotonic])
    return_date = :wxTextCtrl.new(panel, return_date_id)

    :wxSizer.add(
      sizer,
      return_date,
      # flag: wxEXPAND(),
      proportion: 0,
      border: 5
    )

    state = %{
      panel: panel,
      flight_choice_id: flight_choice_id,
      flight_choice: flight_choice,
      start_date_id: start_date_id,
      start_date: start_date,
      return_date_id: return_date_id,
      return_date: return_date
    }

    {panel, state}
  end

  def handle_event(
        {:wx, _, _, _, {:wxCommand, :command_choice_selected, choice, _, _}},
        %{return_date: return_date} = state
      ) do
    case choice do
      @one_way_flight ->
        :wxTextCtrl.setEditable(return_date, false)
        :wxTextCtrl.setBackgroundColour(return_date, @invalid_grey)

      @return_flight ->
        :wxTextCtrl.setEditable(return_date, true)
        :wxTextCtrl.setBackgroundColour(return_date, @white)
    end

    {:noreply, state}
  end
end
