module Keyboardio2mqtt
  # Looks after every attached keyboard: passes Home Assistant's commands on to
  # its availability light.
  class Daemon
    def initialize(finder:, broker:)
      @finder = finder
      @broker = broker
      @topics = {}
    end

    def run
      look_around
      @broker.listen
    end

    def look_around
      @finder.attached_keyboards.each { |keyboard| take_commands_for(keyboard) }
    end

    private

    def take_commands_for(keyboard)
      @broker.on_command(topics_for(keyboard.identity).command_for(keyboard.light)) do |payload|
        show(keyboard, LightCommand.parse(payload))
      end
    end

    def show(keyboard, command)
      keyboard.show(command)
      @broker.report(topics_for(keyboard.identity).state_for(keyboard.light), keyboard.light.state.to_json)
    end

    def topics_for(identity)
      @topics[identity] ||= Topics.new(identity)
    end
  end
end
