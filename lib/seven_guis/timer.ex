defmodule SevenGuis.Timer do
  use WxEx

  @behaviour :wx_object

  @initial_duration_seconds 10

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
    gauge_range = 1000 * @initial_duration_seconds

    # duration range will be set as 10 * duration seconds, which lets users change the
    # duration in 0.1s intervals, up to a limit of 60 seconds.
    duration_min = 10 * 1
    initial_duration = 10 * @initial_duration_seconds
    duration_max = 10 * 60

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
        ~c"0.0"
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

    # Duration time label
    duration_time_label_id = System.unique_integer([:positive, :monotonic])

    duration_time_label =
      :wxStaticText.new(
        panel,
        duration_time_label_id,
        ~c"10.0"
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
      prev_tick_time: prev_tick_time,
      gauge_range: gauge_range,
      elapsed_time_gauge: elapsed_time_gauge,
      elapsed_time_label: elapsed_time_label,
      duration_slider: duration_slider,
      duration_time_label: duration_time_label,
      reset_button: reset_button
    }

    :wxPanel.refresh(panel)
    {panel, state}
  end
end
