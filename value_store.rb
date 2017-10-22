class ValueStore
  def initialize(default, lifetime = 1)
    @value = default
    @max_lifetime = lifetime
    @lifetime = lifetime
  end

  def set(value)
    if value.nil?
      if @lifetime > 0
        @lifetime = @lifetime - 1
      else
        @value = nil
      end
    else
      @lifetime = @max_lifetime
      @value = value
    end
  end

  def get
    @value
  end

  def unset?
    @value.nil?
  end

  def unset!
    @value = nil
  end
end
