require 'pry-byebug'

require_relative 'configuration'
require_relative 'api'
require_relative 'value_store'
require_relative 'emailer'

def timestamp
  Time.now.strftime('%Y-%m-%d %H:%M:%S')
end

def get_last_closed_trade_date(closed_orders)
  return :none unless closed_orders.any?

  last_order = closed_orders.sort_by { |o| o['closetm'] }.last

  DateTime.strptime(last_order['closetm'].to_i.to_s, '%s').to_time
end

def get_last_closed_buy_trade_price(cfg, closed_orders, current_coins)
  return :none if current_coins.nil? || current_coins < cfg.get(:minimum_coin_amount).to_f

  orders = closed_orders.select do |o|
    o.dig('descr', 'type') == 'buy'
  end

  return :none unless orders.any?

  last_order = orders.sort_by { |o| o['closetm'] }.last

  price = last_order['price'].to_f

  return nil if price < cfg.get(:realistic_price_range_min).to_f
  return nil if price > cfg.get(:realistic_price_range_max).to_f

  price
end

def buy(cfg, api, emailer, current_price, daily_high_price, current_coins, closed_orders)
  return false if current_price.nil? || daily_high_price.nil? || current_coins.nil?

  return false if current_coins >= cfg.get(:max_coin_to_hold).to_f

  return false if current_price > daily_high_price * (cfg.get(:buy_point).to_f)

  last_trade_date = get_last_closed_trade_date(closed_orders)
  if last_trade_date != :none
    # Do not buy if the minimum wait after a period has not elapsed
    open_time = last_trade_date + cfg.get(:buy_wait_time).to_i * 60 * 60
    if Time.now < open_time
      puts "#{timestamp} | Cannot buy again before #{open_time.strftime('%Y-%m-%d %H:%M:%S')}"
      return false
    end
  end

  last_buy_trade_price = get_last_closed_buy_trade_price(cfg, closed_orders, current_coins)
  return false if last_buy_trade_price.nil? # API error
  if last_buy_trade_price != :none # trade found
    # Do not buy if the price hasn't fallen since the last buy price
    return false if current_price > last_buy_trade_price * (cfg.get(:buy_point_since_last).to_f)
  end

  amount_in_btc = cfg.get(:buy_in_amount).to_f

  emailer.post("Buy order for #{amount_in_btc} #{cfg.get(:coin_common_name)} @ ~#{current_price} #{cfg.get(:fiat_common_name)}")
  api.market_buy(amount_in_btc)
end

def sell(cfg, api, emailer, current_price, avg_buy_price, current_coins)
  return false if current_price.nil? || avg_buy_price.nil? || current_coins.nil?

  return false if current_coins < cfg.get(:minimum_coin_amount).to_f

  exit_value = avg_buy_price * (cfg.get(:sell_point).to_f)

  return false if exit_value > current_price

  emailer.post("Sell order for #{current_coins} #{cfg.get(:coin_common_name)} @ ~#{current_price} #{cfg.get(:fiat_common_name)}")
  api.market_sell(current_coins)
end

def ratio(nominator, denominator)
  return '---' if nominator.nil? || denominator.nil?

  (((nominator / denominator) - 1.0) * 100.0).round(2)
end

def opt(obj)
  return '---' if obj.nil?

  obj.to_s
end

STDOUT.sync = true

cfg = Configuration.new
api = Api.new(cfg)
emailer = Emailer.new(cfg)

iteration = 0

# Cache because of API instability
current_coins = ValueStore.new(nil, 1)
current_price = ValueStore.new(nil, 3)
daily_high_price = ValueStore.new(nil, 5)

# It is important this is done to ensure we don't leave the bot making bad decisions
# and not know about it because the notifications are down.
emailer.post('Bot started')
puts "#{timestamp} | Bot started"

loop do
  if cfg.get(:hours_disabled)&.split(',')&.map(&:to_i)&.include?(Time.now.hour)
    puts "#{timestamp} | Outside business hours"
    sleep(5 * 60) # Sleep for 5 minutes
    current_price_bak = daily_high_price_bak = nil
    next
  end

  sleep(cfg.get(:poll_interval).to_i) if iteration != 0
  cfg.refresh
  iteration += 1

  # Do not cache these values forever
  current_price_bak = daily_high_price_bak = nil if (iteration % 4) == 0

  open_orders = api.open_orders?
  if open_orders.nil? || open_orders
    puts "#{timestamp} | Order pending" if open_orders
    puts "#{timestamp} | Failed to retrieve open orders" if open_orders.nil?
    next
  end

  current_coins.set(api.get_current_coin_balance)
  if current_coins.unset?
    puts "#{timestamp} | Failed to retrieve current #{cfg.get(:fiat_common_name)} balance amount"
    next
  end

  current_price.set(api.get_current_coin_price)
  if current_price.unset?
    puts "#{timestamp} | Failed to retrieve current market value of #{cfg.get(:coin_common_name)}"
    next
  end

  daily_high_price.set(api.get_daily_high)
  if daily_high_price.unset?
    puts "#{timestamp} | Failed to retrieve daily high price of #{cfg.get(:coin_common_name)}"
    next
  end

  next if current_price.get > daily_high_price.get # This should be impossible

  closed_orders = api.get_closed_orders
  if closed_orders.nil?
    puts "#{timestamp} | Failed to retrieve closed orders"
    next
  end

  avg_buy_price = api.calculate_avg_buy_price(current_coins.get, closed_orders)

  profit = ratio(current_price.get, avg_buy_price)
  price_chg = ratio(current_price.get, daily_high_price.get)

  puts "#{timestamp} | Balance: #{opt(current_coins.get)} #{cfg.get(:coin_common_name)} @ " +
       "#{opt(avg_buy_price)} #{cfg.get(:fiat_common_name)} (#{profit}%), market price now / high: " +
       "#{opt(current_price.get)} / #{opt(daily_high_price.get)} #{cfg.get(:fiat_common_name)} (#{price_chg}%)"

  if sell(cfg, api, emailer, current_price.get, avg_buy_price, current_coins.get) ||
     buy(cfg, api, emailer, current_price.get, daily_high_price.get, current_coins.get, closed_orders)
    sleep(10)
    current_coins.unset!
    current_price.unset!
  end
end
