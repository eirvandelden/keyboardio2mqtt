require "test_helper"

class LosingTheKeyboardTest < Minitest::Test
  IDENTITY = "65644FE61339".freeze
  AVAILABILITY_TOPIC = "keyboardio2mqtt/65644FE61339/availability".freeze
  COMMAND_TOPIC = "keyboardio2mqtt/65644FE61339/availability_light/set".freeze
  RED = %({"state":"ON","brightness":255,"color":{"r":255,"g":0,"b":0}}).freeze
  ONE_DAY = 24 * 60 * 60
  THREE_DAYS = 3 * ONE_DAY

  def setup
    @port = StandInPort.new
    @broker = StandInBroker.new
    @clock = StandInClock.new
    @memory = StandInMemory.new
    @keyboard = Keyboardio2mqtt::Keyboard.new(identity: IDENTITY, port: @port)
    @finder = StandInFinder.new(@keyboard)

    @daemon = Keyboardio2mqtt::Daemon.new(finder: @finder, broker: @broker,
                                          memory: @memory, clock: @clock)
  end

  def test_a_keyboard_that_is_plugged_in_is_available_in_home_assistant
    @daemon.look_around

    assert_equal "online", @broker.reported(AVAILABILITY_TOPIC)
  end

  def test_home_assistant_is_told_where_to_watch_for_a_keyboard_going_away
    @daemon.look_around

    assert_includes @broker.announcement[:availability], { topic: AVAILABILITY_TOPIC }
  end

  def test_a_keyboard_that_is_unplugged_is_reported_unavailable
    @daemon.look_around
    @finder.unplug(IDENTITY)
    @daemon.look_around

    assert_equal "offline", @broker.reported(AVAILABILITY_TOPIC)
  end

  def test_a_keyboard_that_comes_back_is_available_again
    @daemon.look_around
    @finder.unplug(IDENTITY)
    @daemon.look_around
    @finder.plug_in(@keyboard)
    @daemon.look_around

    assert_equal "online", @broker.reported(AVAILABILITY_TOPIC)
  end

  def test_a_keyboard_that_comes_back_is_painted_the_colour_it_was_last_asked_for
    @daemon.look_around
    @broker.deliver(COMMAND_TOPIC, RED)
    @finder.unplug(IDENTITY)
    @daemon.look_around

    @finder.plug_in(@keyboard)
    @daemon.look_around

    assert_equal "availability.color 255 0 0", @port.written.last
  end

  def test_a_keyboard_that_was_already_away_when_the_daemon_started_is_reported_away
    @memory.seen("EF56GH78IJ90", @clock.now)

    @daemon.look_around

    assert_equal "offline", @broker.reported("keyboardio2mqtt/EF56GH78IJ90/availability")
  end

  def test_a_keyboard_that_stays_away_is_not_announced_as_away_over_and_over
    @memory.seen("EF56GH78IJ90", @clock.now)
    @daemon.look_around
    @broker.forget_what_was_reported("keyboardio2mqtt/EF56GH78IJ90/availability")

    @daemon.look_around

    refute @broker.reported?("keyboardio2mqtt/EF56GH78IJ90/availability"),
           "the daemon keeps repeating that a keyboard it lost long ago is away"
  end

  def test_a_keyboard_unseen_for_two_days_disappears_from_home_assistant_altogether
    lose_the_keyboard_for(THREE_DAYS)

    assert @broker.forgotten?("keyboardio2mqtt_65644FE61339"),
           "Home Assistant was never told to drop the keyboard"
  end

  def test_a_keyboard_unseen_for_two_days_is_forgotten_from_the_memory_too
    lose_the_keyboard_for(THREE_DAYS)

    assert_nil @memory.for(IDENTITY, "availability_light"), "the keyboard's light is still remembered"
  end

  def test_a_keyboard_gone_only_a_day_keeps_its_place_in_home_assistant
    lose_the_keyboard_for(ONE_DAY)

    refute @broker.forgotten?("keyboardio2mqtt_65644FE61339"),
           "the keyboard was dropped before its two days were up"
  end

  def test_a_running_daemon_keeps_looking_around_so_a_keyboard_that_goes_is_noticed
    @daemon.run
    @finder.unplug(IDENTITY)
    @clock.next_round

    assert_equal "offline", @broker.reported(AVAILABILITY_TOPIC)
  end

  private

  def lose_the_keyboard_for(seconds)
    @daemon.look_around
    @broker.deliver(COMMAND_TOPIC, RED)
    @finder.unplug(IDENTITY)
    @daemon.look_around

    @clock.advance(seconds)
    @daemon.look_around
  end
end
