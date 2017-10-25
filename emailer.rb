require 'mail'

class Emailer
  def initialize(cfg)
    @cfg = cfg
    @deliver = false

    return if %i[smtp_server smtp_port sender_domain sender_name sender_password sender_address
                  destination_address].any? { |name| @cfg.get(name).nil? || @cfg.get(name).blank? }
    
    options = {
      address: @cfg.get(:smtp_server),
      port: @cfg.get(:smtp_port).to_i,
      domain: @cfg.get(:sender_domain),
      user_name: @cfg.get(:sender_name),
      password: @cfg.get(:sender_password),
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
        cfg = @cfg
        mail = Mail.new do
          from(cfg.get(:sender_address))
          to(cfg.get(:destination_address))
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
