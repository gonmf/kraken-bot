# Cryptocurrency trading bot for kraken exchange

It first buys when the current value drops relative to the daily high value. It keeps buying more
if the price drops relative to the average price of the coins held.

It sells everything at a markup relative to the average coin price.

It buys and sells using upper and lower limit orders. It needs to be able to cancel past orders,
so avoid setting other limit orders manually, because those are not recorded with user-defined
identifiers.

```bash
bundle install

cp config.yml.example config.yml

vi config.yml

bundle exec ruby kraken.rb
```

If the `config.yml` file is edited, the configuration will update without having to restart the program.

**Warnings**

Since limit orders are used, there is the possibility that an order is only partially fulfilled.

Avoid using manually-set limit orders in the same account the program is running on.

Always run the latest version, I am not responsible for you losing your money.
