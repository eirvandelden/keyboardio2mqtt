module Keyboardio2mqtt
  Colour = Data.define(:red, :green, :blue) do
    def self.from_home_assistant(colour)
      new(red: colour.fetch("r"), green: colour.fetch("g"), blue: colour.fetch("b"))
    end

    def to_home_assistant
      { "r" => red, "g" => green, "b" => blue }
    end

    # Asking the keyboard to dim would write to its permanent memory, so a dimmed
    # light is simply a darker colour on the wire.
    def dimmed_to(brightness)
      Colour.new(red: dim(red, brightness), green: dim(green, brightness), blue: dim(blue, brightness))
    end

    private

    def dim(value, brightness)
      value * brightness / FULL_BRIGHTNESS
    end
  end

  Colour::BLACK = Colour.new(red: 0, green: 0, blue: 0)
end
