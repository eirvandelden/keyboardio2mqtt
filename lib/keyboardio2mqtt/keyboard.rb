module Keyboardio2mqtt
  # One physical keyboard: its identity, its name, its availability light, and the
  # port it is reached through.
  class Keyboard
    attr_reader :identity, :name, :light

    def initialize(identity:, port:, name: identity)
      @identity = identity
      @name = name
      @port = port
      @light = AvailabilityLight.new
    end

    def show(command)
      @light.asked_for(command)
      @port.write(@light.command_line)
    end
  end
end
