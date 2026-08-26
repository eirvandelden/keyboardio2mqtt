module Keyboardio2mqtt
  # Looks after every attached keyboard: announces it to Home Assistant, puts back
  # the colour its availability light was last asked for, and passes new commands
  # on. A keyboard that goes away is marked unavailable.
  class Daemon
    GRACE_PERIOD = 48 * 60 * 60

    def initialize(finder:, broker:, memory:, clock: Clock.new)
      @finder = finder
      @broker = broker
      @memory = memory
      @clock = clock
      @attached = {}
      @reported_away = []
      @topics = {}
      @one_at_a_time = Mutex.new
    end

    def run
      @broker.connect(reporting_availability_on: Topics.daemon_availability)
      look_around
      @clock.every_round { look_around }
      @broker.listen
    end

    def look_around
      @one_at_a_time.synchronize { look_around_now }
    end

    private

    def look_around_now
      attached = @finder.attached_keyboards

      attached.each do |keyboard|
        arrive(keyboard) unless @attached.key?(keyboard.identity)
        @memory.seen(keyboard.identity, @clock.now)
      end

      depart(attached.map(&:identity))
      forget_the_long_gone
    end

    def arrive(keyboard)
      @attached[keyboard.identity] = keyboard
      @reported_away.delete(keyboard.identity)
      @broker.announce(**Announcement.new(keyboard).to_home_assistant)
      put_back(keyboard)
      take_commands_for(keyboard)
      @broker.report(topics_for(keyboard.identity).availability, ONLINE)
      Keyboardio2mqtt.logger.info("found the keyboard #{keyboard.identity}, calling it #{keyboard.name.inspect}")
    end

    # Every keyboard the daemon has ever seen, not only those it saw this run: one
    # that was already away at startup still has to be reported away, or Home
    # Assistant goes on showing whatever it was told last time.
    def depart(still_attached)
      ((@attached.keys | @memory.known.keys) - still_attached).each { |identity| lose(identity) }
    end

    def lose(identity)
      return if @reported_away.include?(identity)

      @broker.report(topics_for(identity).availability, OFFLINE)
      @attached.delete(identity)
      @reported_away << identity
      Keyboardio2mqtt.logger.info("lost the keyboard #{identity}")
    end

    def forget_the_long_gone
      @memory.known.each do |identity, last_seen|
        next if @attached.key?(identity)
        next unless @clock.now - last_seen > GRACE_PERIOD

        @broker.forget(Announcement.device_id(identity))
        @memory.forget(identity)
        Keyboardio2mqtt.logger.info("forgetting the keyboard #{identity}; gone for more than two days")
      end
    end

    def put_back(keyboard)
      asked = @memory.for(keyboard.identity, keyboard.light.topic_name)
      show(keyboard, LightCommand.new(asked)) if asked
    end

    def take_commands_for(keyboard)
      @broker.on_command(topics_for(keyboard.identity).command_for(keyboard.light)) do |payload|
        @one_at_a_time.synchronize do
          show(keyboard, LightCommand.parse(payload))
          @memory.remember(keyboard.identity, keyboard.light.topic_name, keyboard.light.state)
        end
      end
    end

    # A keyboard can be unplugged between one command and the next, and its port
    # can be taken by another program. Neither must take the daemon down: the
    # keyboard is simply lost, and it is picked up again on a later round.
    def show(keyboard, command)
      reached = keyboard.show(command)
      @broker.report(topics_for(keyboard.identity).state_for(keyboard.light), keyboard.light.state.to_json)
      lose(keyboard.identity) unless reached
    rescue StandardError => error
      Keyboardio2mqtt.logger.warn("could not reach the keyboard #{keyboard.identity}: #{error.message}")
      lose(keyboard.identity)
    end

    def topics_for(identity)
      @topics[identity] ||= Topics.new(identity)
    end
  end
end
