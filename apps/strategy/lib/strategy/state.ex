defmodule Strategy.State do
  @moduledoc """
  `State` holds the state of a current trader strategy
  """
  @enforce_keys [:symbol, :buy_down_interval, :profit_interval, :tick_size]
  defstruct [
    :symbol,
    :buy_order,
    :sell_order,
    :buy_down_interval,
    :profit_interval,
    :tick_size
  ]
end
