require 'yaml'

class Configuration
  def initialize(logger, file_name = 'config.yml')
    @logger = logger
    @file_name = file_name
    @config = refresh
    raise 'Invalid configuration' unless validate(@config)
    self
  end

  def get(key)
    key = key.to_s

    @config[key]
  end

  def refresh
    new_config = YAML.load_file(@file_name).deep_stringify_keys.freeze

    raise Exception.new unless validate(new_config)

    if new_config != @config
      @logger.log 'Configuration updated' unless @config.nil?
      @config = new_config
    end

    @config
  end

  private

  def validate(cfg)
    option_not_found = %w[
      realistic_price_range_min realistic_price_range_max realistic_coin_amount_max
      trade_price_decimals kraken_api_key kraken_api_secret kraken_user_tier coin_common_name
      fiat_common_name trade_pair_name ticker_pair_name balance_coin_name buy_in_amount buy_point
      sell_point max_coin_to_hold minimum_coin_amount
    ].find { |name| cfg[name].nil? }

    if option_not_found
      @logger.log "Incorrect config: #{option_not_found} missing; check config.yml file"
      return false
    end

    option_not_found = %w[
      realistic_price_range_min realistic_price_range_max realistic_coin_amount_max
      trade_price_decimals kraken_api_key kraken_api_secret kraken_user_tier coin_common_name
      fiat_common_name trade_pair_name ticker_pair_name balance_coin_name buy_in_amount buy_point
      sell_point max_coin_to_hold minimum_coin_amount
    ].find { |name| cfg[name].blank? }

    if option_not_found
      @logger.log "Incorrect config: #{option_not_found} is blank; check config.yml file"
      return false
    end

    true
  end
end
