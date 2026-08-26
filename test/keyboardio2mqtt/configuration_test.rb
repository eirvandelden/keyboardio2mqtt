require "test_helper"

class ConfigurationTest < Minitest::Test
  EXAMPLE = File.expand_path("../../config/keyboardio2mqtt.example.yml", __dir__).freeze

  def test_the_broker_is_read_from_the_file
    configuration = configured("broker" => { "host" => "mqtt.home.arpa", "port" => 8883 })

    assert_equal "mqtt.home.arpa", configuration.broker_host
    assert_equal 8883, configuration.broker_port
  end

  def test_a_broker_with_no_port_of_its_own_is_reached_the_usual_way
    assert_equal 1883, configured("broker" => { "host" => "mqtt.home.arpa" }).broker_port
  end

  def test_the_broker_password_says_where_it_lives_and_never_shows_itself
    configuration = configured("broker" => { "password" => "op://Familie/MqttBroker/password" })

    assert_equal "op://Familie/MqttBroker/password", configuration.broker_password.to_s
  end

  def test_a_broker_username_written_out_in_the_configuration_is_used_as_it_stands
    assert_equal "keyboardio2mqtt", configured("broker" => { "username" => "keyboardio2mqtt" }).broker_username.reveal
  end

  def test_the_memory_lives_where_the_file_says
    configuration = configured("state_file" => "/var/lib/keyboardio2mqtt/state.json")

    assert_equal "/var/lib/keyboardio2mqtt/state.json", configuration.state_file
  end

  def test_a_memory_with_no_home_of_its_own_lives_under_the_users_own_state_directory
    assert_equal File.expand_path("~/.local/state/keyboardio2mqtt/state.json"), configured.state_file
  end

  def test_the_daemon_says_as_much_as_the_configuration_asks_it_to
    assert_equal :info, configured.log_level
    assert_equal :debug, configured("log_level" => "debug").log_level
  end

  def test_a_keyboard_can_be_given_a_name_a_person_would_recognise
    configuration = configured("keyboards" => { "65644FE61339" => "Desk keyboard" })

    assert_equal "Desk keyboard", configuration.name_for("65644FE61339")
  end

  def test_a_keyboard_nobody_has_named_has_no_name_of_its_own
    assert_nil configured.name_for("65644FE61339")
  end

  def test_a_keyboard_whose_serial_number_is_all_digits_is_still_found_in_the_configuration
    assert_equal "Desk keyboard", configured("keyboards" => { 65644136 => "Desk keyboard" }).name_for("65644136")
  end

  def test_the_example_that_ships_with_the_daemon_can_actually_be_read
    configuration = Keyboardio2mqtt::Configuration.read(EXAMPLE)

    assert_equal 1883, configuration.broker_port
    assert_match %r{\Aop://}, configuration.broker_password.to_s
  end

  private

  def configured(said = {})
    Keyboardio2mqtt::Configuration.new(said)
  end
end
