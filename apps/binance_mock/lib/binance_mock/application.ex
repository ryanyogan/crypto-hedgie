defmodule BinanceMock.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {BinanceMock, []}
    ]

    opts = [strategy: :one_for_one, name: BinanceMock.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
