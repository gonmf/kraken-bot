require 'pry-byebug'

require_relative 'logger'
require_relative 'configuration'
require_relative 'api'

def refresh_buy_limit_order(logger, cfg, api, daily_high_price, avg_buy_price, current_coins)
  if current_coins >= cfg.get(:max_coin_to_hold).to_f
    api.cancel_limit_buy_orders
    return
  end

  needed = api.refresh_limit_buy(cfg.get(:buy_in_amount).to_f, daily_high_price, avg_buy_price,
                                 cfg.get(:buy_point).to_f)
  logger.log 'Buy limit order update not needed' unless needed
end

def refresh_sell_limit_order(logger, cfg, api, avg_buy_price, current_coins)
  if avg_buy_price.nil? || current_coins == 0.0
    api.cancel_limit_sell_orders
    return
  end

  needed = api.refresh_limit_sell(current_coins, avg_buy_price, cfg.get(:sell_point).to_f)

  logger.log 'Sell limit order update not needed' unless needed
end

def opt(obj)
  return '---' if obj.nil?

  obj.to_s
end

logger = BotLogger.new
cfg = Configuration.new(logger)
api = Api.new(logger, cfg)

iteration = 0

logger.log 'Bot started'

loop do
  # Sleep 5 minutes between checking if limit orders should be adjusted
  sleep(5 * 60) if iteration != 0

  cfg.refresh
  iteration += 1

  current_coins = api.get_current_coin_balance
  if current_coins.nil?
    logger.log "Failed to retrieve current #{cfg.get(:fiat_common_name)} balance amount"
    next
  end

  daily_high_price = api.get_daily_high
  if daily_high_price.nil?
    logger.log "Failed to retrieve daily high price of #{cfg.get(:coin_common_name)}"
    next
  end

  closed_orders = api.get_closed_orders
  if closed_orders.nil?
    logger.log 'Failed to retrieve closed orders'
    next
  end

  avg_buy_price = api.calculate_avg_buy_price(current_coins, closed_orders)

  logger.log "Balance: #{current_coins} #{cfg.get(:coin_common_name)} @ " +
       "#{opt(avg_buy_price)} #{cfg.get(:fiat_common_name)}, market daily high: " +
       "#{daily_high_price} #{cfg.get(:fiat_common_name)}"

  refresh_buy_limit_order(logger, cfg, api, daily_high_price, avg_buy_price, current_coins)
  refresh_sell_limit_order(logger, cfg, api, avg_buy_price, current_coins)
end
