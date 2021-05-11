defmodule StrategyTest do
  use ExUnit.Case
  doctest Strategy

  test "greets the world" do
    assert Strategy.hello() == :world
  end
end
