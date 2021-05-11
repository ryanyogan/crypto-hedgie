defmodule Strategy.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {
        DynamicSupervisor,
        strategy: :one_for_one, name: Strategy.DynamicSymbolSupervisor
      }
    ]

    opts = [strategy: :one_for_one, name: Strategy.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
