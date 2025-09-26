defmodule SevenGuis.Temperature do
  use WxEx

  @behaviour :wx_object

  def start_link(notebook) do
    :wx_object.start_link(__MODULE__, [notebook], [])
  end

  def init([notebook]) do
    panel = :wxPanel.new(notebook)
    sizer = :wxBoxSizer.new(wxHORIZONTAL())
    :wxWindow.setSizer(panel, sizer)

    # Celsius input

    celsius_input_id = System.unique_integer([:positive, :monotonic])

    celsius_input =
      :wxTextCtrl.new(
        panel,
        celsius_input_id,
        style: wxDEFAULT()
      )

    :wxSizer.add(
      sizer,
      celsius_input,
      # flag: wxEXPAND(),
      proportion: 1,
      border: 5
    )

    # "Celsius =" label

    label_1_id = System.unique_integer([:positive, :monotonic])

    label_1 =
      :wxStaticText.new(
        panel,
        label_1_id,
        "Celsius = "
      )

    :wxSizer.add(
      sizer,
      label_1,
      # flag: wxEXPAND(),
      proportion: 1,
      border: 5
    )

    # Fahrenheit input

    fahrenheit_input_id = System.unique_integer([:positive, :monotonic])

    fahrenheit_input =
      :wxTextCtrl.new(
        panel,
        fahrenheit_input_id,
        style: wxDEFAULT()
      )

    :wxSizer.add(
      sizer,
      fahrenheit_input,
      # flag: wxEXPAND(),
      proportion: 1,
      border: 5
    )

    # Fahrenheit label

    label_2_id = System.unique_integer([:positive, :monotonic])

    label_2 =
      :wxStaticText.new(
        panel,
        label_2_id,
        "Fahrenheit"
      )

    :wxSizer.add(
      sizer,
      label_2,
      # flag: wxEXPAND(),
      proportion: 1,
      border: 5
    )

    state = %{
      panel: panel,
      celsius_input: celsius_input,
      fahrenheit_input: fahrenheit_input
    }

    {panel, state}
  end

  def handle_event({:wx, _, _, _, {:wxCommand, :command_button_clicked, _, _, _}}, state) do
    count = state.count + 1
    state = %{state | count: count}
    :wxStaticText.setLabel(state.text, Integer.to_charlist(count))
    {:noreply, state}
  end

  def f_to_c(temp), do: 5 / 9 * (temp - 32)
  def c_to_f(temp), do: 9 / 5 * temp + 32

  def parse_temp(temp) do
    try do
      float = String.to_float(temp)
      {:ok, float}
    rescue
      ArgumentError ->
        try do
          float = String.to_integer(temp) / 1
          {:ok, float}
        rescue
          ArgumentError -> :error
        end
    end
  end
end
