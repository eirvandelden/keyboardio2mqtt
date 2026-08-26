require "json"
require "logger"

module Keyboardio2mqtt
  NAME = "keyboardio2mqtt".freeze
  FULL_BRIGHTNESS = 255

  # The words Home Assistant uses for a light that is lit or dark.
  ON = "ON".freeze
  OFF = "OFF".freeze

  class << self
    attr_writer :logger

    def logger
      @logger ||= Logger.new($stdout)
    end
  end
end

require "keyboardio2mqtt/colour"
require "keyboardio2mqtt/availability_light"
require "keyboardio2mqtt/light_command"
require "keyboardio2mqtt/focus_port"
require "keyboardio2mqtt/keyboard"
require "keyboardio2mqtt/topics"
require "keyboardio2mqtt/daemon"
