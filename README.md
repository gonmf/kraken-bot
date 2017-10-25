# Cryptocurrency trading bot for kraken exchange
i
It keeps buying small amounts when the value drops a certain percentage amount, relative to the average price for the last 24 hours. It waits some hours and further price drops before successive buys.

It sells everything when the entire coin holdings have risen in price a certain percentage amount.

Since it buys and sells using margin orders you can expect some deviation from the profit margin and buy points set.

```bash
bundle install

cp config.yml.example config.yml

vi config.yml

bundle exec ruby kraken.rb
```

If the `config.yml` file is edited, the configuration will updated without having to restart the program.

For the good behavior of the program it is best for it to have sole control of the account (no third party buying and selling).
If the account is shared, at least avoid selling small amounts. The program goes through the last buy orders to try to
come up with an average entry position of the coins held.

Always run the latest version, I am not responsible for you losing your money.
