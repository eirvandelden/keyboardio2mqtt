module Keyboardio2mqtt
  # Where one keyboard's commands arrive and its state is reported.
  class Topics
    def initialize(identity)
      @identity = identity
    end

    def command_for(light)
      "#{for_light(light)}/set"
    end

    def state_for(light)
      "#{for_light(light)}/state"
    end

    private

    def for_light(light)
      "#{NAME}/#{@identity}/#{light.topic_name}"
    end
  end
end
