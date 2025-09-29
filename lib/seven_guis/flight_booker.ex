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
    :wxTextCtrl.connect(start_date, :command_text_updated)

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
    :wxTextCtrl.connect(return_date, :command_text_updated)

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

  # Finite state machine for flight booker constraints
  def next_step(
        %{
          flight_kind: flight_kind,
          start_date: start_date,
          start_date_text: start_date_text,
          # :valid | :invalid
          start_date_validity: start_date_validity,
          return_date: return_date,
          return_date_text: return_date_text,
          # :disabled | :valid | :invalid
          return_date_validity: return_date_validity,
          # true | false
          booking_enabled: booking_enabled
        } = data_state
      ) do
    # Only enable return date iff choice is "return flight"
    return_date_validity =
      case flight_kind do
        @one_way_flight -> :disabled
        @return_flight -> :enabled
      end

    parsed_start_date = Date.from_iso8601(start_date_text)

    {start_date_validity, start_date} =
      case parsed_start_date do
        {:ok, start_date} -> {:valid, start_date}
        {:error, _} -> {:invalid, :error}
      end

    parsed_return_date = Date.from_iso8601(return_date_text)

    {return_date_validity, return_date} =
      case {return_date_validity, parsed_return_date} do
        {:disabled, _} -> {:disabled, :error}
        {:enabled, {:ok, return_date}} -> {:valid, return_date}
        {:enabled, {:error, _}} -> {:invalid, :error}
      end

    # Check if return date is strictly after start date in case of return flights
    flight_valid = flight_kind == @one_way_flight || return_date >= start_date

    # When a non-disabled textfield has an ill-formatted date, it should disable the button
    booking_enabled =
      start_date_validity == :valid && return_date_validity in [:disabled, :valid] && flight_valid

    %{
      data_state
      | start_date_validity: start_date_validity,
        start_date: start_date,
        return_date_validity: return_date_validity,
        return_date: return_date,
        booking_enabled: booking_enabled
    }
  end
end
