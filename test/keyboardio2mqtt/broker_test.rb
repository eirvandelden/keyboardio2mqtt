require "test_helper"

class BrokerTest < Minitest::Test
  COMMAND_TOPIC = "keyboardio2mqtt/65644FE61339/availability_light/set".freeze
  STATE_TOPIC = "keyboardio2mqtt/65644FE61339/availability_light/state".freeze

  def test_reporting_the_lights_state_keeps_it_on_the_broker_for_home_assistant_to_find
    client = StandInMqttClient.new

    Keyboardio2mqtt::Broker.new(client).report(STATE_TOPIC, %({"state":"ON"}))

    assert_equal [ { topic: STATE_TOPIC, payload: %({"state":"ON"}), retain: true, qos: 0 } ],
                 client.published
  end

  def test_the_broker_offers_home_assistant_the_announcement_a_keyboard_actually_makes
    keyboard = Keyboardio2mqtt::Keyboard.new(identity: "65644FE61339", port: StandInPort.new)
    client = StandInMqttClient.new

    Keyboardio2mqtt::Broker.new(client).announce(**Keyboardio2mqtt::Announcement.new(keyboard).to_home_assistant)

    offered = client.published.first
    assert_equal "homeassistant/device/keyboardio2mqtt_65644FE61339/config", offered[:topic]
    assert offered[:retain], "Home Assistant would forget the keyboard as soon as it looked away"

    described = JSON.parse(offered[:payload])
    assert_equal "all", described["availability_mode"]
    assert_equal 2, described["availability"].size
    assert_equal 1, described["components"].size
  end

  def test_listening_for_the_lights_commands_subscribes_to_its_command_topic
    client = StandInMqttClient.new

    Keyboardio2mqtt::Broker.new(client).on_command(COMMAND_TOPIC) { }

    assert_equal [ COMMAND_TOPIC ], client.subscribed
  end

  def test_a_command_that_arrives_reaches_whoever_asked_for_that_topic
    client = StandInMqttClient.new(arriving: [ [ COMMAND_TOPIC, "turn it red" ] ])
    broker = Keyboardio2mqtt::Broker.new(client)
    heard = []

    broker.on_command(COMMAND_TOPIC) { |payload| heard << payload }
    broker.listen

    assert_equal [ "turn it red" ], heard
  end

  def test_a_command_for_a_topic_nobody_asked_about_is_ignored
    client = StandInMqttClient.new(arriving: [ [ "somebody/elses/topic", "not ours" ] ])

    assert_silent { Keyboardio2mqtt::Broker.new(client).listen }
  end
end
