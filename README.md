# cryptocurrency trading bot for kraken exchange

It keeps buying small amounts when the value drops a certain percentage amount, relative to the average price for the last 24 hours. It waits some hours before successive buys.

It sells everything when the entire coin holdings have risen in price a certain percentage amount.

```ruby
bundle install

cp .env.example .env

vi .env

bundle exec ruby kraken.rb
```
