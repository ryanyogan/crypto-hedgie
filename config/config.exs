import Config

config :logger, level: :info

config :strategy,
  binance_client: BinanceMock
