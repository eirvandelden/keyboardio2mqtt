module Keyboardio2mqtt
  # The whole board, lit as one light. Holds what it was last asked for, and knows
  # the command line the firmware wants.
  #
  # The firmware spells it "color" because Kaleidoscope is American throughout.
  # This is the one place the two spellings meet.
  class AvailabilityLight
    WHAT_IT_IS = "availability light".freeze
    SET_COLOUR = "availability.color".freeze

    def initialize
      @colour = Colour::BLACK
      @brightness = FULL_BRIGHTNESS
      @on = false
    end

    def topic_name
      WHAT_IT_IS.tr(" ", "_")
    end

    def asked_for(command)
      @on = command.on?
      @colour = command.colour || @colour
      @brightness = command.brightness || @brightness
    end

    def state
      { "state" => @on ? ON : OFF, "brightness" => @brightness, "color" => @colour.to_home_assistant }
    end

    def command_line
      "#{SET_COLOUR} #{shown.red} #{shown.green} #{shown.blue}"
    end

    private

    # Off is black on the wire; the colour itself is kept for the next time the
    # light is switched on.
    def shown
      return Colour::BLACK unless @on

      @colour.dimmed_to(@brightness)
    end
  end
end
