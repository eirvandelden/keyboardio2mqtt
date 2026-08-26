require "test_helper"
require "stringio"

class LeavingThePortAloneTest < Minitest::Test
  COMMAND_TOPIC = "keyboardio2mqtt/65644FE61339/availability_light/set".freeze
  PORT = "/dev/cu.usbmodem65644FE613391".freeze
  STATE_TOPIC = "keyboardio2mqtt/65644FE61339/availability_light/state".freeze
  RED = %({"state":"ON","brightness":255,"color":{"r":255,"g":0,"b":0}}).freeze
  GREEN = %({"state":"ON","brightness":255,"color":{"r":0,"g":255,"b":0}}).freeze

  def setup
    @files = StandInFiles.new
    @broker = StandInBroker.new
    daemon_reaching_the_keyboard_through(@files)
  end

  def test_writing_a_colour_opens_the_port_writes_once_and_closes_it_again
    ask_for RED

    assert_equal 1, @files.times_opened
    assert_equal [ "availability.color 255 0 0" ], @files.written
    assert @files.all_closed?, "the daemon is still holding the port"
  end

  def test_the_keyboards_reply_is_read_so_nothing_is_left_for_the_next_command
    ask_for RED

    assert @files.all_replies_read?, "the keyboard's reply was left sitting on the port"
  end

  def test_sending_several_colours_in_a_row_opens_the_port_once_for_each_of_them
    ask_for RED
    ask_for GREEN

    assert_equal 2, @files.times_opened
    assert_equal [ "availability.color 255 0 0", "availability.color 0 255 0" ], @files.written
    assert @files.all_closed?, "the daemon left the port open between two colours"
  end

  def test_a_port_another_program_is_holding_does_not_stop_the_daemon
    what_the_daemon_says do
      daemon_reaching_the_keyboard_through(StandInFiles.new(held_by_somebody_else: true))
      ask_for RED
    end

    assert_equal({ "state" => "ON", "brightness" => 255, "color" => { "r" => 255, "g" => 0, "b" => 0 } },
                 @broker.reported_settings(STATE_TOPIC))
  end

  def test_a_port_another_program_is_holding_says_so_rather_than_failing_quietly
    said = what_the_daemon_says do
      daemon_reaching_the_keyboard_through(StandInFiles.new(held_by_somebody_else: true))
      ask_for RED
    end

    assert_match(/#{PORT}/, said)
  end

  private

  def daemon_reaching_the_keyboard_through(files)
    keyboard = Keyboardio2mqtt::Keyboard.new(identity: "65644FE61339",
                                             port: Keyboardio2mqtt::FocusPort.new(PORT, files: files))

    Keyboardio2mqtt::Daemon.new(finder: StandInFinder.new(keyboard), broker: @broker).run
  end

  def what_the_daemon_says
    said = StringIO.new
    before = Keyboardio2mqtt.logger
    Keyboardio2mqtt.logger = Logger.new(said)
    yield

    said.string
  ensure
    Keyboardio2mqtt.logger = before
  end

  def ask_for(payload)
    @broker.deliver(COMMAND_TOPIC, payload)
  end
end
