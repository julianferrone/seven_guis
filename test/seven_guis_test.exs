defmodule SevenGuisTest do
  use ExUnit.Case
  doctest SevenGuis

  test "greets the world" do
    assert SevenGuis.hello() == :world
  end
end
