# cryptocurrency trading bot for kraken exchange

It keeps buying small amounts when the value drops a certain percentage amount, relative to the average price for the last 24 hours. It waits some hours and further price drops before successive buys.

It sells everything when the entire coin holdings have risen in price a certain percentage amount.

```ruby
bundle install

cp .env.example .env

vi .env

bundle exec ruby kraken.rb
```

For the good behavior of the program it is best for it to have sole control of the account (no third party buying and selling).
If the account is shared, at least avoid selling small amounts. The program goes through the last buy orders to try to
come up with an average entry position of the coins held.

Always run the latest version, I am not responsible for you losing your money.
