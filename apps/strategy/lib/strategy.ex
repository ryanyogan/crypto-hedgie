defmodule Strategy do
  @moduledoc """
  Documentation for `Strategy`.
  """

  alias Streamer.Binance.TradeEvent

  def send_event(%TradeEvent{} = event) do
    GenServer.cast(:trader, event)
  end
end
