defmodule Strategy.Leader do
  use GenServer
  require Logger

  @binance_client Application.get_env(:strategy, :binance_client)

  defmodule State do
    defstruct symbol: nil, settings: nil, traders: []
  end

  defmodule TraderData do
    defstruct pid: nil, ref: nil, state: nil
  end

  def start_link(symbol) do
    GenServer.start_link(
      __MODULE__,
      symbol,
      name: :"#{__MODULE__}-#{symbol}"
    )
  end

  def notify(:trader_state_updated, trader_state) do
    GenServer.call(
      :"#{__MODULE__}-#{trader_state.symbol}",
      {:update_trader_state, trader_state}
    )
  end

  @impl true
  def init(symbol) do
    {:ok, %State{symbol: symbol}, {:continue, :start_traders}}
  end

  @impl true
  def handle_continue(:start_traders, %{symbol: symbol} = state) do
    settings = fetch_symbol_settings(symbol)
    trader_state = fresh_trader_state(settings)

    traders =
      for _i <- 1..settings.chunks,
          do: start_new_trader(trader_state)

    {:noreply, %{state | settings: settings, traders: traders}}
  end

  @impl true
  def handle_call(
        {:update_trader_state, new_trader_state},
        {trader_pid, _},
        %{traders: traders} = state
      ) do
    case Enum.find_index(traders, &(&1.pid == trader_pid)) do
      nil ->
        Logger.warn("Tried to update the state of that leader is not aware of")
        {:reply, :ok, state}

      index ->
        older_trader_data = Enum.at(traders, index)
        new_trader_data = %{older_trader_data | :state => new_trader_state}

        {:reply, :ok, %{state | :traders => List.replace_at(traders, index, new_trader_data)}}
    end
  end

  @impl true
  def handle_info(
        {:DOWN, _ref, :process, trader_pid, :normal},
        %{traders: traders, symbol: symbol, settings: settings} = state
      ) do
    Logger.info("#{symbol} trader finished trade -- restarting")

    case Enum.find_index(traders, &(&1.pid == trader_pid)) do
      nil ->
        Logger.warn(
          "Tried to restart finished #{symbol} " <>
            "trader that leader is not aware of"
        )

        {:noreply, state}

      index ->
        new_trader_data = start_new_trader(fresh_trader_state(settings))
        new_traders = List.replace_at(traders, index, new_trader_data)
        {:noreply, %{state | traders: new_traders}}
    end
  end

  @impl true
  def handle_info(
        {:DOWN, _ref, :process, trader_pid, _reason},
        %{traders: traders, symbol: symbol} = state
      ) do
    Logger.error("#{symbol} trader died - trying to restart")

    case Enum.find_index(traders, &(&1.pid == trader_pid)) do
      nil ->
        Logger.warn(
          "Tried to restart #{symbol} trader " <>
            "but failed to find its cached state"
        )

        {:noreply, state}

      index ->
        trader_data = Enum.at(traders, index)
        new_trader_data = start_new_trader(trader_data.state)
        new_traders = List.replace_at(traders, index, new_trader_data)

        {:noreply, %{state | traders: new_traders}}
    end
  end

  defp fetch_symbol_settings(symbol) do
    tick_size = fetch_tick_size(symbol)

    %{
      symbol: symbol,
      chunks: 1,
      buy_down_interval: Decimal.new("0.0001"),
      profit_interval: Decimal.new("-0.0012"),
      tick_size: tick_size
    }
  end

  defp fetch_tick_size(symbol) do
    @binance_client.get_exchange_info()
    |> elem(1)
    |> Map.get(:symbols)
    |> Enum.find(&(&1["symbol"] == symbol))
    |> Map.get("filters")
    |> Enum.find(&(&1["filterType"] == "PRICE_FILTER"))
    |> Map.get("tickSize")
    |> Decimal.new()
  end

  defp fresh_trader_state(settings) do
    struct(Strategy.State, settings)
  end

  defp start_new_trader(%Strategy.State{} = state) do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        :"Strategy.DynamicTraderSupervisor-#{state.symbol}",
        {Strategy.Trader, state}
      )

    ref = Process.monitor(pid)

    %TraderData{pid: pid, ref: ref, state: state}
  end
end
