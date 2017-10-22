require 'mail'

class Emailer
  def initialize
    @deliver = false

    return if %w[SMTP_SERVER SMTP_PORT SENDER_DOMAIN SENDER_NAME SENDER_PASSWORD SENDER_ADDRESS
                  DESTINATION_ADDRESS].any? { |config| ENV[config].blank? }

    options = {
      address: ENV['SMTP_SERVER'],
      port: ENV['SMTP_PORT'].to_i,
      domain: ENV['SENDER_DOMAIN'],
      user_name: ENV['SENDER_NAME'],
      password: ENV['SENDER_PASSWORD'],
      authentication: 'plain',
      enable_starttls_auto: true
    }

    Mail.defaults do
      delivery_method :smtp, options
    end

    @deliver = true
  end

  def post(body)
    return unless @deliver

    loop do
      begin
        mail = Mail.new do
          from(ENV['SENDER_ADDRESS'])
          to(ENV['DESTINATION_ADDRESS'])
          subject('Kraken Bot Notification')
          body(body)
        end

        mail.deliver!
        break
      rescue Exception => e
        puts 'Email notification failed; will try again in 1 minute...'
        sleep(60)
      end
    end
  end
end
