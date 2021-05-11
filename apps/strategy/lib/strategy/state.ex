defmodule Strategy.State do
  @moduledoc """
  `State` holds the state of a current trader strategy
  """
  @enforce_keys [:symbol, :profit_interval, :tick_size]
  defstruct [
    :symbol,
    :buy_order,
    :sell_order,
    :profit_interval,
    :tick_size
  ]
end
