# Stands in for the MQTT broker. Tests hand it a command with `deliver` and read
# back what was reported.
class StandInBroker
  def initialize
    @listeners = {}
    @reports = {}
  end

  def on_command(topic, &listener)
    @listeners[topic] = listener
  end

  def report(topic, payload)
    @reports[topic] = payload
  end

  def listen
    @listening = true
  end

  def listening?
    @listening
  end

  def deliver(topic, payload)
    listener = @listeners.fetch(topic) { raise "nobody is listening to #{topic}" }
    listener.call(payload)
  end

  def reported(topic)
    @reports.fetch(topic) { raise "nothing was reported to #{topic}" }
  end

  def reported_settings(topic)
    JSON.parse(reported(topic))
  end
end
