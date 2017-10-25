class BotLogger
  def initialize
    STDOUT.sync = true

    @repeat = 0
    @last_message = nil
  end

  def log(message)
    if @last_message == message
      @repeat += 1
      puts "#{timestamp} | #{message} (#{@repeat})"
    else
      @repeat = 0
      @last_message = message
      puts "#{timestamp} | #{message}"
    end
  end

  private

  def timestamp
    Time.now.strftime('%Y-%m-%d %H:%M:%S')
  end
end
