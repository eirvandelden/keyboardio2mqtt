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
      @broker.connect(reporting_availability_on: Topics.daemon_availability)
      look_around
      @broker.listen
    end

    def look_around
      @finder.attached_keyboards.each { |keyboard| arrive(keyboard) }
    end

    private

    def arrive(keyboard)
      @broker.announce(**Announcement.new(keyboard).to_home_assistant)
      take_commands_for(keyboard)
      @broker.report(topics_for(keyboard.identity).availability, ONLINE)
      Keyboardio2mqtt.logger.info("found the keyboard #{keyboard.identity}, calling it #{keyboard.name.inspect}")
    end

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
