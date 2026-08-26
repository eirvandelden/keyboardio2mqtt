require "test_helper"

class AppearingInHomeAssistantTest < Minitest::Test
  def setup
    @broker = StandInBroker.new
    keyboard = Keyboardio2mqtt::Keyboard.new(identity: "65644FE61339", port: StandInPort.new)

    Keyboardio2mqtt::Daemon.new(finder: StandInFinder.new(keyboard), broker: @broker,
                                memory: StandInMemory.new, clock: StandInClock.new).run
  end

  def test_a_keyboard_that_is_plugged_in_appears_in_home_assistant_as_one_device
    assert_equal "keyboardio2mqtt_65644FE61339", announcement[:device_id]
    assert_equal "65644FE61339", announcement[:device][:name]
  end

  def test_the_device_carries_one_availability_light
    assert_equal [ "Availability light" ], lights.map { |light| light[:name] }
  end

  def test_the_light_is_offered_to_home_assistant_as_a_light
    assert_equal [ "light" ], lights.map { |light| light[:platform] }
  end

  def test_the_light_takes_a_colour_and_a_brightness
    light = lights.first

    assert_equal "keyboardio2mqtt/65644FE61339/availability_light/set", light[:command_topic]
    assert_equal "keyboardio2mqtt/65644FE61339/availability_light/state", light[:state_topic]
    assert_equal [ "rgb" ], light[:supported_color_modes]
    assert light[:brightness], "the light does not offer brightness"
  end

  def test_the_light_keeps_its_place_in_home_assistant_across_restarts
    assert_equal [ "keyboardio2mqtt_65644FE61339_availability_light" ], lights.map { |light| light[:unique_id] }
  end

  def test_the_light_is_reachable_only_while_both_the_daemon_and_the_keyboard_are_here
    assert_equal [ "keyboardio2mqtt/availability", "keyboardio2mqtt/65644FE61339/availability" ],
                 announcement[:availability].map { |watched| watched[:topic] }
    assert_equal "all", announcement[:availability_mode]
  end

  def test_a_running_daemon_says_where_it_will_report_that_it_is_here
    assert_equal "keyboardio2mqtt/availability", @broker.connected_reporting_on
  end

  def test_a_keyboard_that_has_been_given_a_name_shows_that_name_in_home_assistant
    broker = StandInBroker.new
    keyboard = Keyboardio2mqtt::Keyboard.new(identity: "65644FE61339", name: "Desk keyboard",
                                             port: StandInPort.new)

    Keyboardio2mqtt::Daemon.new(finder: StandInFinder.new(keyboard), broker: broker,
                                memory: StandInMemory.new, clock: StandInClock.new).run

    assert_equal "Desk keyboard", broker.announcement[:device][:name]
  end

  private

  def announcement
    @broker.announcement
  end

  def lights
    announcement[:components].values
  end
end
