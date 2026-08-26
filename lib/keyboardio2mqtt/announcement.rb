module Keyboardio2mqtt
  # How a keyboard introduces itself to Home Assistant: one device carrying one
  # availability light.
  class Announcement
    MANUFACTURER = "Keyboardio".freeze
    MODEL = "Model 100".freeze
    COLOUR_MODE = "rgb".freeze

    # The light is only reachable while the daemon and its own keyboard are both
    # here.
    BOTH_MUST_BE_HERE = "all".freeze

    def self.device_id(identity)
      "#{NAME}_#{identity}"
    end

    def initialize(keyboard)
      @keyboard = keyboard
      @topics = Topics.new(keyboard.identity)
    end

    def to_home_assistant
      {
        device_id: device_id,
        device: { identifiers: device_id, name: @keyboard.name, manufacturer: MANUFACTURER, model: MODEL },
        origin: { name: NAME },
        availability: [ { topic: Topics.daemon_availability }, { topic: @topics.availability } ],
        availability_mode: BOTH_MUST_BE_HERE,
        components: { light.topic_name => light_component }
      }
    end

    private

    def light
      @keyboard.light
    end

    def device_id
      self.class.device_id(@keyboard.identity)
    end

    def light_component
      {
        platform: "light",
        name: light.name.capitalize,
        unique_id: "#{device_id}_#{light.topic_name}",
        schema: :json,
        command_topic: @topics.command_for(light),
        state_topic: @topics.state_for(light),
        supported_color_modes: [ COLOUR_MODE ],
        brightness: true
      }
    end
  end
end
