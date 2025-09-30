defmodule SevenGuis.Timer do
  use WxEx

  @behaviour :wx_object

  @initial_duration_seconds 5

  # in milliseconds
  @tick_period 100

  def start_link(notebook) do
    :wx_object.start_link(__MODULE__, [notebook], [])
  end

  def init([notebook]) do
    panel = :wxPanel.new(notebook)

    flex_grid_sizer = :wxGridBagSizer.new(vgap: 10, hgap: 10)
    :wxWindow.setSizer(panel, flex_grid_sizer)

    prev_tick_time = DateTime.utc_now()

    # Static elapsed time label
    :wxGridBagSizer.add(
      flex_grid_sizer,
      :wxStaticText.new(
        panel,
        System.unique_integer([:positive, :monotonic]),
        ~c"Elapsed time:"
      ),
      {0, 0},
      flag: wxALIGN_RIGHT()
    )

    # gauge range will be set as 1000 * duration seconds, which lets us use milliseconds
    # when we do time diffs to calculate how to update the gauge
    gauge_range = seconds_to_elapsed(@initial_duration_seconds)

    # duration range will be set as 10 * duration seconds, which lets users change the
    # duration in 0.1s intervals, up to a limit of 60 seconds.
    duration_min = seconds_to_duration(1)
    initial_duration = seconds_to_duration(@initial_duration_seconds)
    duration_max = seconds_to_duration(60)

    # Elapsed time gauge
    elapsed_time_gauge_id = System.unique_integer([:positive, :monotonic])

    elapsed_time_gauge =
      :wxGauge.new(
        panel,
        elapsed_time_gauge_id,
        gauge_range
      )

    :wxGridBagSizer.add(flex_grid_sizer, elapsed_time_gauge, {0, 1})

    # Elapsed time label
    elapsed_time_label_id = System.unique_integer([:positive, :monotonic])

    elapsed_time_label =
      :wxStaticText.new(
        panel,
        elapsed_time_label_id,
        elapsed_value_to_text(0)
      )

    :wxGridBagSizer.add(
      flex_grid_sizer,
      elapsed_time_label,
      {0, 2},
      flag: wxALIGN_RIGHT()
    )

    # Static duration label
    :wxGridBagSizer.add(
      flex_grid_sizer,
      :wxStaticText.new(
        panel,
        System.unique_integer([:positive, :monotonic]),
        ~c"Duration:"
      ),
      {1, 0},
      flag: wxALIGN_RIGHT()
    )

    # Duration slider

    duration_slider_id = System.unique_integer([:positive, :monotonic])

    duration_slider =
      :wxSlider.new(
        panel,
        duration_slider_id,
        initial_duration,
        duration_min,
        duration_max
      )

    :wxGridBagSizer.add(
      flex_grid_sizer,
      duration_slider,
      {1, 1},
      flag: wxEXPAND()
    )

    :wxSlider.connect(duration_slider, :command_slider_updated)

    # Duration time label
    duration_time_label_id = System.unique_integer([:positive, :monotonic])

    duration_time_label =
      :wxStaticText.new(
        panel,
        duration_time_label_id,
        duration_value_to_text(initial_duration)
      )

    :wxGridBagSizer.add(
      flex_grid_sizer,
      duration_time_label,
      {1, 2},
      flag: wxALIGN_RIGHT()
    )

    # Reset button
    reset_button_id = System.unique_integer([:positive, :monotonic])

    reset_button =
      :wxButton.new(
        panel,
        reset_button_id,
        label: ~c"Reset"
      )

    :wxGridBagSizer.add(
      flex_grid_sizer,
      reset_button,
      {2, 0},
      span: {1, 3},
      flag: wxALIGN_CENTER()
    )

    state = %{
      # Informational state
      prev_tick_time: prev_tick_time,
      elapsed: 0.0,
      duration: initial_duration,
      # GUI elements
      elapsed_time_gauge: elapsed_time_gauge,
      elapsed_time_label: elapsed_time_label,
      duration_slider: duration_slider,
      duration_time_label: duration_time_label,
      reset_button: reset_button
    }

    :wxPanel.refresh(panel)
    send(self(), :tick)
    {panel, state}
  end

  def handle_event(
        {:wx, _, _, _, {:wxCommand, :command_slider_updated, _, duration_value, _}},
        %{
          duration_time_label: duration_time_label,
          elapsed_time_gauge: elapsed_time_gauge
        } = state
      ) do
    # Update duration time label
    duration_text = duration_value_to_text(duration_value)
    :wxStaticText.setLabel(duration_time_label, duration_text)

    # Update gauge range
    elapsed_range = duration_value |> duration_to_seconds() |> seconds_to_elapsed()
    :wxGauge.setRange(elapsed_time_gauge, elapsed_range)

    current_tick_time = DateTime.utc_now()
    state = %{state | duration: duration_value, prev_tick_time: current_tick_time}
    send(self(), :tick)
    {:noreply, state}
  end

  def handle_info(
        :tick,
        %{
          duration: duration,
          elapsed: elapsed,
          elapsed_time_gauge: elapsed_time_gauge,
          elapsed_time_label: elapsed_time_label,
          prev_tick_time: prev_tick_time
        } = state
      ) do
    IO.inspect("---")

    current_tick_time =
      DateTime.utc_now()
      |> IO.inspect(label: "current_tick_time")

    prev_gauge_value =
      :wxGauge.getValue(elapsed_time_gauge)
      |> IO.inspect(label: "prev_gauge_value")

    delta_time =
      DateTime.diff(current_tick_time, prev_tick_time, :millisecond)
      |> IO.inspect(label: "delta_time")

    elapsed =
      min(prev_gauge_value + delta_time, duration_to_elapsed(duration))
      |> IO.inspect(label: "elapsed")

    if elapsed_to_seconds(elapsed) < duration_to_seconds(duration) do
      Process.send_after(self(), :tick, @tick_period)
    end

    :wxGauge.getRange(elapsed_time_gauge)
    |> IO.inspect(label: "elapsed_time_gauge range")

    :wxGauge.setValue(elapsed_time_gauge, elapsed)
    :wxStaticText.setLabel(elapsed_time_label, elapsed_value_to_text(elapsed))

    state = %{
      state
      | prev_tick_time: current_tick_time,
        elapsed: elapsed
    }

    {:noreply, state}
  end

  def duration_value_to_text(duration) do
    ~c"#{duration / 10.0}s"
  end

  def elapsed_value_to_text(elapsed) do
    ~c"#{elapsed / 1000.0}s"
  end

  def duration_to_seconds(duration), do: duration / 10
  def seconds_to_duration(seconds), do: seconds * 10

  def elapsed_to_seconds(elapsed), do: elapsed / 1000
  def seconds_to_elapsed(seconds), do: Kernel.trunc(seconds * 1000)

  def elapsed_to_duration(elapsed), do: elapsed_to_seconds(elapsed) |> seconds_to_duration()
  def duration_to_elapsed(duration), do: duration_to_seconds(duration) |> seconds_to_elapsed()
end
