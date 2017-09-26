require 'pry'
require 'json'
require 'net/http'
require 'dotenv/load'
require 'kraken_client'

def get_last_trade_price(client)
  client.public.ticker(ENV['TICKER_PAIR_NAME'])[ENV['TICKER_PAIR_NAME']]['c'][0].to_f
end

def market_buy(client, amount_in_btc)
  puts "#{Time.now} | --- BUYING #{amount_in_btc} #{ENV['BALANCE_COIN_NAME']} ---"

  order = {
    pair: ENV['TRADE_PAIR_NAME'],
    type: 'buy',
    ordertype: 'market',
    volume: amount_in_btc
  }

  client.private.add_order(order)
end

def market_sell(client, amount_in_btc)
  puts "#{Time.now} | --- SELLING #{amount_in_btc} #{ENV['BALANCE_COIN_NAME']} ---"

  order = {
    pair: ENV['TRADE_PAIR_NAME'],
    type: 'sell',
    ordertype: 'market',
    volume: amount_in_btc
  }

  client.private.add_order(order)
end

def get_current_coin_balance(client)
  client.private.balance[ENV['BALANCE_COIN_NAME']].to_f.round(4)
end

def open_orders?(client)
  orders = client.private.open_orders['open']

  orders.values.any? do |h|
    h.dig('descr', 'pair') == ENV['TRADE_PAIR_NAME'] && h.dig('descr', 'ordertype') == 'market'
  end
end

def get_last_closed_buy_trade(client)
  orders = client.private.closed_orders

  orders = orders['closed'].values.select do |o|
    o['status'] == 'closed' && o.dig('descr', 'pair') == ENV['TRADE_PAIR_NAME'] &&
      o.dig('descr', 'type') == 'buy' && o.dig('descr', 'ordertype') == 'market' &&
      o['vol'].to_f == ENV['BUY_IN_AMOUNT'].to_f
  end

  return nil unless orders.any?

  trade = orders.sort_by { |o| o['closetm'] }.last

  OpenStruct.new(price: trade['price'].to_f, time: DateTime.strptime(trade['closetm'].to_i.to_s, '%s').to_time)
end

def get_daily_high(client)
  ohlc = client.public.ohlc(pair: ENV['TICKER_PAIR_NAME'], interval: 1440)

  line = ohlc[ENV['TICKER_PAIR_NAME']]&.last
  return nil if line.nil? || line.count != 8

  line[2].to_f
end

def buy(client, current_price, daily_high_price, current_coins)
  return false if current_price.nil? || daily_high_price.nil? || current_coins.nil?

  return false if current_coins >= ENV['MAX_COIN_TO_HOLD'].to_f

  return false if current_price >= daily_high_price * (ENV['BUY_POINT'].to_f)

  last_buy = get_last_closed_buy_trade(client)

  unless last_buy.nil?
    # Do not buy if the minimum wait after a period has not elapsed
    return false if Time.now - last_buy.time < ENV['BUY_WAIT_TIME'].to_i * 60 * 60

    # Do not buy if the price hasn't fallen since the last buy price
    return false if last_buy.price * (ENV['BUY_POINT'].to_f) < current_price
  end

  market_buy(client)
end

def calculate_avg_buy_price(client, current_coins)
  orders = client.private.closed_orders

  orders = orders['closed'].values.select do |o|
    o['status'] == 'closed' && o.dig('descr', 'pair') == ENV['TRADE_PAIR_NAME'] &&
      o.dig('descr', 'type') == 'buy' && o.dig('descr', 'ordertype') == 'market' &&
      o['vol'].to_f == ENV['BUY_IN_AMOUNT'].to_f
  end

  return nil unless orders.any?

  idx = 0
  total_btc = 0.0
  total_spent = 0.0
  while idx < orders.count
    spent = orders[idx]['cost'].to_f
    amount = orders[idx]['vol'].to_f

    break if total_btc + amount > current_coins

    total_spent += spent
    total_btc += amount

    break if total_btc == current_coins

    ++idx
  end

  total_spent / total_btc
end

def sell(client, current_price, avg_buy_price, current_coins)
  return false if current_price.nil? || avg_buy_price.nil? || current_coins.nil?

  return false if current_coins < 0.0001

  exit_value = avg_buy_price * (ENV['SELL_POINT'].to_f)

  return false if exit_value > current_price

  market_sell(client, current_coins)
end

KrakenClient.configure do |config|
  config.api_key = ENV['KRAKEN_API_KEY']
  config.api_secret = ENV['KRAKEN_API_SECRET']
  config.base_uri = 'https://api.kraken.com'
  config.api_version = 0
  config.limiter = false
  config.tier = ENV['KRAKEN_USER_TIER'].to_i
end

client = KrakenClient.load

loop do
  sleep(ENV['POLL_INTERVAL'].to_i)

  next if open_orders?(client)

  current_coins = get_current_coin_balance(client)

  current_price = get_last_trade_price(client)

  avg_buy_price = calculate_avg_buy_price(client, current_coins)

  daily_high_price = get_daily_high(client)

  puts "#{Time.now} | Own: #{current_coins || 'n/a'} #{ENV['BALANCE_COIN_NAME']}, avg buy value: #{avg_buy_price || 'n/a'}, last market price: #{current_price || 'n/a'} EUR, daily high: #{daily_high_price || 'n/a'} EUR"

  next if buy(client, current_price, daily_high_price, current_coins)

  sell(client, current_price, avg_buy_price, current_coins)
end
