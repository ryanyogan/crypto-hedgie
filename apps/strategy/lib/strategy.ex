defmodule Strategy do
  @moduledoc """
  Documentation for `Strategy`.
  """

  def start_trading(symbol) when is_binary(symbol) do
    symbol = String.upcase(symbol)

    {:ok, _pid} =
      DynamicSupervisor.start_child(
        Strategy.DynamicSymbolSupervisor,
        {Strategy.SymbolSupervisor, symbol}
      )
  end
end
