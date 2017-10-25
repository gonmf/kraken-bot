require 'kraken_client'

class Api
  def initialize(cfg)
    @cfg = cfg

    KrakenClient.configure do |config|
      config.api_key = @cfg.get(:kraken_api_key)
      config.api_secret = @cfg.get(:kraken_api_secret)
      config.base_uri = 'https://api.kraken.com'
      config.api_version = 0
      config.limiter = false
      config.tier = @cfg.get(:kraken_user_tier).to_i
    end

    @client = KrakenClient.load
  end

  def get_closed_orders
    orders = @client.private.closed_orders
    return nil if orders.nil?

    orders['closed'].values.select do |o|
      o['status'] == 'closed' && o.dig('descr', 'pair') == @cfg.get(:trade_pair_name)
    end
  rescue Exception => e
    nil
  end

  def get_current_coin_price
    ticker = @client.public.ticker(@cfg.get(:ticker_pair_name))
    return nil if ticker.nil?

    price = ticker[@cfg.get(:ticker_pair_name)]['c'][0].to_f

    return nil if price < @cfg.get(:realistic_price_range_min).to_f
    return nil if price > @cfg.get(:realistic_price_range_max).to_f

    price
  rescue Exception => e
    nil
  end

  def market_buy(amount_in_btc)
    puts "#{timestamp} | Buying #{amount_in_btc} #{@cfg.get(:coin_common_name)}..."

    order = {
      pair: @cfg.get(:trade_pair_name),
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
    current_coins = current_coins.round(@cfg.get(:sell_price_decimals).to_i)

    puts "#{timestamp} | Selling #{current_coins} #{@cfg.get(:coin_common_name)}..."

    order = {
      pair: @cfg.get(:trade_pair_name),
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
    balance = @client.private.balance[@cfg.get(:balance_coin_name)]
    return nil if balance.nil?

    balance = balance.to_f.round(4)

    balance = balance < @cfg.get(:minimum_coin_amount).to_f ? 0.0 : balance
    return nil if balance > @cfg.get(:realistic_coin_amount_max).to_f

    balance
  rescue Exception => e
    nil
  end

  def open_orders?
    orders = @client.private.open_orders
    return nil if orders.nil?

    orders['open'].values.any? do |h|
      h.dig('descr', 'pair') == @cfg.get(:trade_pair_name) && h.dig('descr', 'ordertype') == 'market'
    end
  rescue Exception => e
    nil
  end

  def get_daily_high
    ohlc = @client.public.ohlc(pair: @cfg.get(:ticker_pair_name), interval: 1440)
    return nil if ohlc.nil?

    line = ohlc[@cfg.get(:ticker_pair_name)]&.last
    return nil if line.nil? || line.count != 8

    price = line[2].to_f

    return nil if price < @cfg.get(:realistic_price_range_min).to_f
    return nil if price > @cfg.get(:realistic_price_range_max).to_f

    price
  rescue Exception => e
    nil
  end

  def calculate_avg_buy_price(current_coins, closed_orders)
    return nil if current_coins.nil? || current_coins < @cfg.get(:minimum_coin_amount).to_f

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

    return nil if total_btc < @cfg.get(:minimum_coin_amount).to_f

    price = total_spent / total_btc

    return nil if price < @cfg.get(:realistic_price_range_min).to_f
    return nil if price > @cfg.get(:realistic_price_range_max).to_f

    price
  rescue Exception => e
    nil
  end
end
