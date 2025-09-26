defmodule SevenGuis.Temperature do
  use WxEx

  @behaviour :wx_object

  @white {255, 255, 255}
  @error_red {255, 150, 150}
  @invalid_grey {200, 200, 200}

  def start_link(notebook) do
    :wx_object.start_link(__MODULE__, [notebook], [])
  end

  def init([notebook]) do
    panel = :wxPanel.new(notebook)
    sizer = :wxBoxSizer.new(wxHORIZONTAL())
    :wxWindow.setSizer(panel, sizer)

    # Celsius input

    celsius_id = System.unique_integer([:positive, :monotonic])

    celsius_input =
      :wxTextCtrl.new(
        panel,
        celsius_id,
        style: wxDEFAULT()
      )

    :wxTextCtrl.connect(celsius_input, :command_text_updated)

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

    fahrenheit_id = System.unique_integer([:positive, :monotonic])

    fahrenheit_input =
      :wxTextCtrl.new(
        panel,
        fahrenheit_id,
        style: wxDEFAULT()
      )

    :wxTextCtrl.connect(fahrenheit_input, :command_text_updated)

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
      celsius_id: celsius_id,
      celsius_input: celsius_input,
      fahrenheit_id: fahrenheit_id,
      fahrenheit_input: fahrenheit_input,
    }

    {panel, state}
  end

  def handle_event(
        {:wx, celsius_id, _, _, {:wxCommand, :command_text_updated, _, _, _}},
        %{
          celsius_id: celsius_id,
          celsius_input: celsius_input,
          fahrenheit_input: fahrenheit_input
        } = state
      ) do
    text = :wxTextCtrl.getValue(celsius_input)
    temp = parse_temp(text)

    case temp do
      {:ok, celsius} ->
        fahrenheit = c_to_f(celsius)
        :wxTextCtrl.setBackgroundColour(celsius_input, @white)
        :wxTextCtrl.setBackgroundColour(fahrenheit_input, @white)
        :wxTextCtrl.changeValue(fahrenheit_input, Float.to_charlist(fahrenheit))
        :wxTextCtrl.refresh(celsius_input)
        state = %{state | celsius_input: celsius_input, fahrenheit_input: fahrenheit_input}
        {:noreply, state}

      :error ->
        :wxTextCtrl.setBackgroundColour(celsius_input, @error_red)
        :wxTextCtrl.setBackgroundColour(fahrenheit_input, @invalid_grey)
        :wxTextCtrl.refresh(celsius_input)
        state = %{state | celsius_input: celsius_input}
        {:noreply, state}
    end
  end

  def handle_event(
        {:wx, fahrenheit_id, _, _, {:wxCommand, :command_text_updated, _, _, _}},
        %{
          fahrenheit_id: fahrenheit_id,
          celsius_input: celsius_input,
          fahrenheit_input: fahrenheit_input
        } = state
      ) do
    text = :wxTextCtrl.getValue(fahrenheit_input)
    temp = parse_temp(text)

    case temp do
      {:ok, fahrenheit} ->
        celsius = f_to_c(fahrenheit)
        :wxTextCtrl.setBackgroundColour(celsius_input, @white)
        :wxTextCtrl.setBackgroundColour(fahrenheit_input, @white)
        :wxTextCtrl.changeValue(celsius_input, Float.to_charlist(celsius))
        :wxWindow.refresh(fahrenheit_input)
        state = %{state | celsius_input: celsius_input, fahrenheit_input: fahrenheit_input}
        {:noreply, state}

      :error ->
        :wxTextCtrl.setBackgroundColour(celsius_input, @invalid_grey)
        :wxTextCtrl.setBackgroundColour(fahrenheit_input, @error_red)
        :wxTextCtrl.refresh(fahrenheit_input)
        state = %{state | fahrenheit_input: fahrenheit_input}
        {:noreply, state}
    end
  end

  def f_to_c(temp), do: 5 / 9 * (temp - 32)
  def c_to_f(temp), do: 9 / 5 * temp + 32

  def parse_temp(temp) do
    temp = to_string(temp)

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
