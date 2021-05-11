defmodule Strategy.Trader do
  use GenServer, restart: :temporary
  require Logger

  alias Decimal, as: D
  alias Strategy.{State, Leader}
  alias Streamer.Binance.TradeEvent

  @binance_client Application.get_env(:strategy, :binance_client)

  def start_link(%State{} = state) do
    GenServer.start_link(__MODULE__, state)
  end

  @impl true
  def init(%State{symbol: symbol} = state) do
    symbol = String.upcase(symbol)

    Logger.info("Initializing new trader strategy for #{symbol}")

    Phoenix.PubSub.subscribe(
      Streamer.PubSub,
      "TRADE_EVENTS:#{symbol}"
    )

    {:ok, state}
  end

  @impl true
  def handle_info(
        %TradeEvent{price: price},
        %State{
          symbol: symbol,
          budget: budget,
          buy_order: nil,
          buy_down_interval: buy_down_interval,
          tick_size: tick_size,
          step_size: step_size
        } = state
      ) do
    quantity = calculate_quantity(budget, price, step_size)
    price = calculate_buy_price(price, buy_down_interval, tick_size)

    Logger.info("Placing BUY order for #{symbol} @ #{price}, quantity: #{quantity}")

    {:ok, %Binance.OrderResponse{} = order} =
      @binance_client.order_limit_buy(symbol, quantity, price, "GTC")

    new_state = %{state | buy_order: order}
    Leader.notify(:trader_state_updated, new_state)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(
        %TradeEvent{buyer_order_id: order_id, quantity: quantity},
        %State{
          symbol: symbol,
          buy_order: %Binance.OrderResponse{
            price: buy_price,
            order_id: order_id,
            orig_qty: quantity
          },
          profit_interval: profit_interval,
          tick_size: tick_size
        } = state
      ) do
    sell_price = calculate_sell_price(buy_price, profit_interval, tick_size)

    Logger.info(
      "Buy order filled, placing SELL order for " <>
        "#{symbol} @ #{sell_price}, quantity: #{quantity}"
    )

    {:ok, %Binance.OrderResponse{} = order} =
      @binance_client.order_limit_sell(symbol, quantity, sell_price, "GTC")

    new_state = %{state | sell_order: order}
    Leader.notify(:trader_state_updated, new_state)

    {:noreply, new_state}
  end

  @impl true
  def handle_info(
        %TradeEvent{seller_order_id: order_id, quantity: quantity},
        %State{
          sell_order: %Binance.OrderResponse{
            order_id: order_id,
            orig_qty: quantity
          }
        } = state
      ) do
    Logger.info("Trade finished, trader strategy will now exit.")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(%TradeEvent{}, state) do
    {:noreply, state}
  end

  defp calculate_sell_price(buy_price, profit_interval, tick_size) do
    fee = D.new("1.001")
    original_price = D.mult(D.new(buy_price), fee)

    net_target_price =
      D.mult(
        original_price,
        D.add("1.0", profit_interval)
      )

    gross_target_price = D.mult(net_target_price, fee)

    D.to_float(
      D.mult(
        D.div_int(gross_target_price, tick_size),
        tick_size
      )
    )
  end

  defp calculate_buy_price(price, buy_down_interval, tick_size) do
    current_price = D.new(price)

    # This price needs to hash with tick size, so
    # will normalize the return after the exact price,
    # as the market goes you can be a tick or two off
    exact_buy_price =
      D.sub(
        current_price,
        D.mult(current_price, buy_down_interval)
      )

    D.to_float(
      D.mult(
        D.div_int(exact_buy_price, tick_size),
        tick_size
      )
    )
  end

  defp calculate_quantity(budget, price, step_size) do
    price = D.new(price)

    exact_target_quantity = D.div(budget, price)

    D.to_float(
      D.mult(
        D.div_int(exact_target_quantity, step_size),
        step_size
      )
    )
  end
end
