defmodule BinanceMock.State do
  @moduledoc """
  Holds the all the mocked `OrderBooks`, `PubSub Subscriptions`,
  and `fake_order_id` which starts at `1`.
  """
  defstruct order_books: %{},
            subscriptions: [],
            fake_order_id: 1
end
