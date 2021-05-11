defmodule Strategy.SymbolSupervisor do
  use Supervisor
  require Logger

  def start_link(symbol) do
    Supervisor.start_link(
      __MODULE__,
      symbol,
      name: :"#{__MODULE__}-#{symbol}"
    )
  end

  @impl true
  def init(symbol) do
    Logger.info("Starting new supervision tree to trade on #{symbol}")

    Supervisor.init(
      [
        {
          DynamicSupervisor,
          strategy: :one_for_one, name: :"Strategy.DynamicTraderSupervisor-#{symbol}"
        },
        {Strategy.Leader, symbol}
      ],
      strategy: :one_for_all
    )
  end
end
