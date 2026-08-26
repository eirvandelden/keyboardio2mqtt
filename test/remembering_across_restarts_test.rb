require "test_helper"
require "tmpdir"
require "fileutils"

class RememberingAcrossRestartsTest < Minitest::Test
  DAEMON_AVAILABILITY = "keyboardio2mqtt/availability".freeze
  COMMAND_TOPIC = "keyboardio2mqtt/65644FE61339/availability_light/set".freeze
  STATE_TOPIC = "keyboardio2mqtt/65644FE61339/availability_light/state".freeze
  RED_AT_HALF = %({"state":"ON","brightness":128,"color":{"r":255,"g":0,"b":0}}).freeze

  def setup
    @directory = Dir.mktmpdir
    @path = File.join(@directory, "state.json")
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_a_daemon_that_is_restarted_paints_the_keyboard_the_colour_it_was_showing_before
    start_the_daemon { |broker| broker.deliver(COMMAND_TOPIC, RED_AT_HALF) }

    port, = start_the_daemon

    assert_equal "availability.color 128 0 0", port.written.last
  end

  def test_a_restarted_daemon_tells_home_assistant_where_the_light_stands
    start_the_daemon { |broker| broker.deliver(COMMAND_TOPIC, RED_AT_HALF) }

    _, broker = start_the_daemon

    assert_equal({ "state" => "ON", "brightness" => 128, "color" => { "r" => 255, "g" => 0, "b" => 0 } },
                 broker.reported_settings(STATE_TOPIC))
  end

  def test_a_keyboard_nobody_has_touched_yet_is_left_alone
    port, = start_the_daemon

    assert_empty port.written
  end

  def test_a_memory_that_cannot_be_read_is_set_aside_and_the_daemon_starts_fresh
    File.write(@path, "this is not what we wrote")

    port, = start_the_daemon

    assert_empty port.written
    assert_path_exists "#{@path}.unreadable", "the unreadable memory was not kept for inspection"
  end

  def test_a_memory_holding_something_other_than_light_settings_is_set_aside_too
    File.write(@path, "[]")

    port, = start_the_daemon

    assert_empty port.written
    assert_path_exists "#{@path}.unreadable", "the unusable memory was not kept for inspection"
  end

  def test_a_daemon_that_dies_is_seen_to_have_gone_because_it_left_word_before_connecting
    client = StandInMqttClient.new

    Keyboardio2mqtt::Broker.new(client).connect(reporting_availability_on: DAEMON_AVAILABILITY)

    assert_equal({ topic: DAEMON_AVAILABILITY, payload: "offline", retain: true }, client.will)
  end

  def test_a_connected_daemon_says_it_is_here
    client = StandInMqttClient.new

    Keyboardio2mqtt::Broker.new(client).connect(reporting_availability_on: DAEMON_AVAILABILITY)

    assert_includes client.published,
                    { topic: DAEMON_AVAILABILITY, payload: "online", retain: true, qos: 0 }
  end

  private

  def start_the_daemon
    port = StandInPort.new
    broker = StandInBroker.new
    keyboard = Keyboardio2mqtt::Keyboard.new(identity: "65644FE61339", port: port)

    Keyboardio2mqtt::Daemon.new(finder: StandInFinder.new(keyboard), broker: broker,
                                memory: Keyboardio2mqtt::RememberedState.new(@path),
                                clock: StandInClock.new).run
    yield broker if block_given?

    [ port, broker ]
  end
end
