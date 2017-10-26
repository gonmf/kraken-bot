require 'kraken_client'

class Api
  def initialize(logger, cfg)
    @logger = logger
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

  def refresh_limit_buy(amount_in_btc, daily_high_price, avg_buy_price, buy_point)
    reference_price = avg_buy_price.nil? ? daily_high_price : avg_buy_price
    buy_price = (reference_price * buy_point).round(@cfg.get(:currency_decimals))

    options = {
      amount_in_btc: amount_in_btc,
      buy_price: buy_price
    }

    return false if @prev_buy_options == options

    cancel_limit_buy_orders

    loop do
      @logger.log "Setting buy limit order at #{buy_price}..."
      add_limit_buy_order(amount_in_btc, buy_price)
      break if synchronous_get_open_limit_orders('buy').count == 1
    end

    @logger.log 'Buy limit order updated'
    @prev_buy_options = options
    true
  rescue Exception => e
    @logger.log 'Exception @ limit_buy'
    true
  end

  def refresh_limit_sell(current_coins, avg_buy_price, sell_point)
    sell_price = (avg_buy_price * sell_point).round(@cfg.get(:currency_decimals))

    options = {
      current_coins: current_coins,
      sell_price: sell_price
    }

    return false if @prev_sell_options == options

    cancel_limit_sell_orders

    loop do
      @logger.log "Setting sell limit order at #{sell_price}..."
      add_limit_sell_order(current_coins, sell_price)
      break if synchronous_get_open_limit_orders('sell').count == 1
    end

    @logger.log 'Sell limit order updated'
    @prev_sell_options = options
    true
  rescue Exception => e
    @logger.log 'Exception @ limit_sell'
    true
  end

  def cancel_limit_buy_orders
    @logger.log 'Clearing past buy limit orders...'
    loop do
      orders = synchronous_get_open_limit_orders('buy')
      break if orders.count == 0

      @logger.log "#{orders.count} orders remaining..."
      clear_limit_orders(orders)
    end
  rescue Exception => e
    @logger.log 'Exception @ cancel_limit_buy_orders'
    sleep(3)
    true
  end

  def cancel_limit_sell_orders
    @logger.log 'Clearing past sell limit orders...'
    loop do
      orders = synchronous_get_open_limit_orders('sell')
      break if orders.count == 0

      @logger.log "#{orders.count} orders remaining..."
      clear_limit_orders(orders)
    end
  rescue Exception => e
    @logger.log 'Exception @ cancel_limit_sell_orders'
    sleep(3)
    true
  end

  def get_current_coin_balance
    balance = @client.private.balance[@cfg.get(:balance_coin_name)]
    return nil if balance.nil?

    balance = coin_trunc(balance.to_f)

    return nil if balance > @cfg.get(:realistic_coin_amount_max).to_f

    balance
  rescue Exception => e
    nil
  end

  def get_daily_high
    ohlc = @client.public.ohlc(pair: @cfg.get(:ticker_pair_name), interval: 1440)
    return nil if ohlc.nil?

    line = ohlc[@cfg.get(:ticker_pair_name)]&.last
    return nil if line.nil? || line.count != 8

    price = line[2].to_f.round(@cfg.get(:currency_decimals))

    return nil if price < @cfg.get(:realistic_price_range_min).to_f
    return nil if price > @cfg.get(:realistic_price_range_max).to_f

    price
  rescue Exception => e
    nil
  end

  def calculate_avg_buy_price(current_coins, closed_orders)
    return nil if current_coins == 0.0

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

    total_btc = coin_trunc(total_btc)
    return nil if total_btc == 0.0

    price = (total_spent / total_btc).round(@cfg.get(:currency_decimals))

    return nil if price < @cfg.get(:realistic_price_range_min).to_f
    return nil if price > @cfg.get(:realistic_price_range_max).to_f

    price
  rescue Exception => e
    sleep(5)
    nil
  end

  private

  def clear_limit_orders(orders) # Synchronous
    orders.each do |order|
      begin
        @client.private.cancel_order(txid: order.dig('userref'))
      rescue Exception => e
      end
      sleep(1)
    end
  end

  def add_limit_buy_order(amount_in_btc, buy_price)
    order = {
      pair: @cfg.get(:trade_pair_name),
      type: 'buy',
      ordertype: 'limit',
      price: buy_price,
      volume: amount_in_btc,
      userref: rand(1..(2**31-1))
    }

    @client.private.add_order(order)
    sleep(1)
  rescue Exception => e
    @logger.log 'Exception @ add_limit_buy_order'
    sleep(3)
  end

  def add_limit_sell_order(current_coins, sell_price)
    order = {
      pair: @cfg.get(:trade_pair_name),
      type: 'sell',
      ordertype: 'limit',
      price: sell_price,
      volume: current_coins,
      userref: rand(1..(2**31-1))
    }

    @client.private.add_order(order)
    sleep(1)
  rescue Exception => e
    @logger.log 'Exception @ add_limit_sell_order'
    sleep(3)
  end

  def synchronous_get_open_limit_orders(type)
    sleep(1)
    loop do
      begin
        orders = @client.private.open_orders
        if orders.nil?
          sleep(3)
          next
        end

        return orders['open'].values.select do |h|
          h.dig('descr', 'pair') == @cfg.get(:trade_pair_name) && h.dig('descr', 'ordertype') == 'limit' &&
            h.dig('descr', 'type') == type && h.dig('userref') != nil && h.dig('status') == 'open'
        end
      rescue Exception => e
        sleep(10)
      end
    end
  end

  def coin_trunc(value)
    digits = @cfg.get(:coin_decimals)

    (value.to_f * (10**digits)).floor / (10**digits).to_f
  end
end
