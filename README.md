# cryptocurrency trading bot for kraken exchange

It keeps buying small amounts when the value drops a certain percentage amount, relative to the daily high price.

It sells everything when the entire coin holdings have risen in price a certain percentage amount.

```ruby
bundle install

cp .env.example .env

vi .env

ruby kraken.rb
```
