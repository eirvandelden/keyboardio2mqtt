require "test_helper"

class LightingTheKeyboardTest < Minitest::Test
  COMMAND_TOPIC = "keyboardio2mqtt/65644FE61339/availability_light/set".freeze
  STATE_TOPIC = "keyboardio2mqtt/65644FE61339/availability_light/state".freeze

  def setup
    @port = StandInPort.new
    @broker = StandInBroker.new
    keyboard = Keyboardio2mqtt::Keyboard.new(identity: "65644FE61339", port: @port)

    Keyboardio2mqtt::Daemon.new(finder: StandInFinder.new(keyboard), broker: @broker).run
  end

  def test_the_daemon_listens_for_commands_for_as_long_as_it_runs
    assert @broker.listening?, "the daemon ran without ever listening to the broker"
  end

  def test_asking_for_red_lights_the_keyboard_red
    ask_for %({"state":"ON","brightness":255,"color":{"r":255,"g":0,"b":0}})

    assert_equal [ "availability.color 255 0 0" ], @port.written
  end

  def test_asking_for_red_reports_the_light_red_to_home_assistant
    ask_for %({"state":"ON","brightness":255,"color":{"r":255,"g":0,"b":0}})

    assert_equal({ "state" => "ON", "brightness" => 255, "color" => { "r" => 255, "g" => 0, "b" => 0 } },
                 @broker.reported_settings(STATE_TOPIC))
  end

  def test_a_colour_asked_for_without_a_brightness_burns_at_full
    ask_for %({"state":"ON","color":{"r":255,"g":0,"b":0}})

    assert_equal [ "availability.color 255 0 0" ], @port.written
  end

  def test_dimming_the_light_to_half_sends_half_the_colour_to_the_keyboard
    ask_for %({"state":"ON","brightness":128,"color":{"r":255,"g":0,"b":0}})

    assert_equal [ "availability.color 128 0 0" ], @port.written
  end

  def test_dimming_the_light_reports_the_colour_and_the_brightness_apart
    ask_for %({"state":"ON","brightness":128,"color":{"r":255,"g":0,"b":0}})

    assert_equal({ "state" => "ON", "brightness" => 128, "color" => { "r" => 255, "g" => 0, "b" => 0 } },
                 @broker.reported_settings(STATE_TOPIC))
  end

  def test_turning_the_light_off_fades_the_board_to_dark
    ask_for %({"state":"ON","brightness":255,"color":{"r":255,"g":0,"b":0}})
    ask_for %({"state":"OFF"})

    assert_equal "availability.color 0 0 0", @port.written.last
  end

  def test_a_light_that_is_off_still_remembers_the_colour_it_was_given
    ask_for %({"state":"ON","brightness":255,"color":{"r":255,"g":0,"b":0}})
    ask_for %({"state":"OFF"})

    assert_equal({ "state" => "OFF", "brightness" => 255, "color" => { "r" => 255, "g" => 0, "b" => 0 } },
                 @broker.reported_settings(STATE_TOPIC))
  end

  def test_turning_the_light_back_on_brings_back_the_colour_it_had
    ask_for %({"state":"ON","brightness":255,"color":{"r":255,"g":0,"b":0}})
    ask_for %({"state":"OFF"})
    ask_for %({"state":"ON"})

    assert_equal "availability.color 255 0 0", @port.written.last
  end

  private

  def ask_for(payload)
    @broker.deliver(COMMAND_TOPIC, payload)
  end
end
