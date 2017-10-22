require 'kraken_client'

class Api
  def initialize
    KrakenClient.configure do |config|
      config.api_key = ENV['KRAKEN_API_KEY']
      config.api_secret = ENV['KRAKEN_API_SECRET']
      config.base_uri = 'https://api.kraken.com'
      config.api_version = 0
      config.limiter = false
      config.tier = ENV['KRAKEN_USER_TIER'].to_i
    end

    @client = KrakenClient.load
  end

  def get_closed_orders
    orders = @client.private.closed_orders
    return nil if orders.nil?

    orders['closed'].values.select do |o|
      o['status'] == 'closed' && o.dig('descr', 'pair') == ENV['TRADE_PAIR_NAME']
    end
  end

  def get_current_coin_price
    ticker = @client.public.ticker(ENV['TICKER_PAIR_NAME'])
    return nil if ticker.nil?

    price = ticker[ENV['TICKER_PAIR_NAME']]['c'][0].to_f

    return nil if price < ENV['REALISTIC_PRICE_RANGE_MIN'].to_f
    return nil if price > ENV['REALISTIC_PRICE_RANGE_MAX'].to_f

    price
  rescue Exception => e
    nil
  end

  def market_buy(amount_in_btc)
    puts "#{timestamp} | Buying #{amount_in_btc} #{ENV['COIN_COMMON_NAME']}..."

    order = {
      pair: ENV['TRADE_PAIR_NAME'],
      type: 'buy',
      ordertype: 'market',
      volume: amount_in_btc
    }

    @client.private.add_order(order)
    true
  rescue Exception => e
    puts "#{timestamp} | Exception @ market_buy"
    false
  end

  def market_sell(current_coins)
    current_coins = current_coins.round(ENV['SELL_PRICE_DECIMALS'].to_i)

    puts "#{timestamp} | Selling #{current_coins} #{ENV['COIN_COMMON_NAME']}..."

    order = {
      pair: ENV['TRADE_PAIR_NAME'],
      type: 'sell',
      ordertype: 'market',
      volume: current_coins
    }

    @client.private.add_order(order)
    true
  rescue Exception => e
    puts "#{timestamp} | Exception @ market_sell"
    false
  end

  def get_current_coin_balance
    balance = @client.private.balance[ENV['BALANCE_COIN_NAME']]
    return nil if balance.nil?

    balance = balance.to_f.round(4)

    balance = balance < ENV['MINIMUM_COIN_AMOUNT'].to_f ? 0.0 : balance
    return nil if balance > ENV['REALISTIC_COIN_AMOUNT_MAX'].to_f

    balance
  rescue Exception => e
    nil
  end

  def open_orders?
    orders = @client.private.open_orders
    return nil if orders.nil?

    orders['open'].values.any? do |h|
      h.dig('descr', 'pair') == ENV['TRADE_PAIR_NAME'] && h.dig('descr', 'ordertype') == 'market'
    end
  rescue Exception => e
    nil
  end

  def get_daily_high
    ohlc = @client.public.ohlc(pair: ENV['TICKER_PAIR_NAME'], interval: 1440)
    return nil if ohlc.nil?

    line = ohlc[ENV['TICKER_PAIR_NAME']]&.last
    return nil if line.nil? || line.count != 8

    price = line[2].to_f

    return nil if price < ENV['REALISTIC_PRICE_RANGE_MIN'].to_f
    return nil if price > ENV['REALISTIC_PRICE_RANGE_MAX'].to_f

    price
  rescue Exception => e
    nil
  end

  def calculate_avg_buy_price(current_coins, closed_orders)
    return nil if current_coins.nil? || current_coins < ENV['MINIMUM_COIN_AMOUNT'].to_f

    return nil if closed_orders.nil?

    orders = closed_orders.select do |o|
      o.dig('descr', 'type') == 'buy'
    end

    idx = 0
    total_btc = 0.0
    total_spent = 0.0
    while idx < orders.count && total_btc < current_coins
      spent = orders[idx]['cost'].to_f
      amount = orders[idx]['vol'].to_f

      total_spent += spent
      total_btc += amount

      idx += 1
    end

    return nil if total_btc < ENV['MINIMUM_COIN_AMOUNT'].to_f

    price = total_spent / total_btc

    return nil if price < ENV['REALISTIC_PRICE_RANGE_MIN'].to_f
    return nil if price > ENV['REALISTIC_PRICE_RANGE_MAX'].to_f

    price
  rescue Exception => e
    nil
  end
end
