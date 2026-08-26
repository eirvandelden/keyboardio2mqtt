require "test_helper"

class KeyboardFinderTest < Minitest::Test
  SERIAL_NUMBER = "65644FE61339".freeze
  PORT = "/dev/cu.usbmodem65644FE613391".freeze

  # What macOS says about the USB bus, trimmed to the lines that matter: a hub,
  # the keyboard hanging off it, and a phone that is none of our business.
  WITH_THE_KEYBOARD = <<~IOREG.freeze
    +-o Root  <class IORegistryEntry, id 0x100000100, retain 35>
      +-o 3-Port USB 2.1 Hub@02100000  <class IOUSBHostDevice, id 0x10001043b>
      | |   "idProduct" = 21521
      | |   "USB Product Name" = "3-Port USB 2.1 Hub"
      | |   "idVendor" = 3034
      | +-o Model 100@02110000  <class IOUSBHostDevice, id 0x100010480>
      | |     "idProduct" = 6
      | |     "USB Product Name" = "Model 100"
      | |     "USB Vendor Name" = "Keyboardio"
      | |     "idVendor" = 13462
      | |     "USB Serial Number" = "65644FE61339"
      | +-o iPhone@02124300  <class IOUSBHostDevice, id 0x100010570>
      |       "USB Serial Number" = "00008030001474D12690802E"
      |       "idVendor" = 1452
      |       "idProduct" = 4776
  IOREG

  WITHOUT_THE_KEYBOARD = <<~IOREG.freeze
    +-o Root  <class IORegistryEntry, id 0x100000100, retain 35>
      +-o iPhone@02124300  <class IOUSBHostDevice, id 0x100010570>
            "USB Serial Number" = "00008030001474D12690802E"
            "idVendor" = 1452
            "idProduct" = 4776
  IOREG

  def test_a_keyboard_on_the_usb_bus_is_known_by_its_serial_number
    assert_equal [ SERIAL_NUMBER ], finding(WITH_THE_KEYBOARD).attached_keyboards.map(&:identity)
  end

  def test_a_keyboard_is_reached_through_the_port_named_after_its_serial_number
    ports = StandInPorts.new(PORT)

    finding(WITH_THE_KEYBOARD, ports: ports).attached_keyboards

    assert_equal [ "/dev/cu.usbmodem65644FE61339*" ], ports.asked_for
  end

  def test_a_device_that_is_not_a_keyboardio_is_left_alone
    assert_empty finding(WITHOUT_THE_KEYBOARD).attached_keyboards
  end

  def test_a_keyboard_whose_port_has_not_appeared_yet_is_left_out
    assert_empty finding(WITH_THE_KEYBOARD, ports: StandInPorts.new).attached_keyboards
  end

  def test_a_keyboard_is_called_what_the_configuration_calls_it
    finder = finding(WITH_THE_KEYBOARD,
                     configuration: Keyboardio2mqtt::Configuration.new("keyboards" => { SERIAL_NUMBER => "Desk keyboard" }))

    assert_equal [ "Desk keyboard" ], finder.attached_keyboards.map(&:name)
  end

  def test_a_keyboard_nobody_has_named_is_called_what_it_is
    assert_equal [ "Keyboardio Model 100" ], finding(WITH_THE_KEYBOARD).attached_keyboards.map(&:name)
  end

  def test_a_keyboard_that_stays_plugged_in_is_the_same_keyboard_from_one_round_to_the_next
    finder = finding(WITH_THE_KEYBOARD)

    assert_same finder.attached_keyboards.first, finder.attached_keyboards.first,
                "a keyboard that never went away was built afresh, losing the colour it was showing"
  end

  def test_a_keyboard_that_is_unplugged_is_no_longer_attached
    shell = StandInShell.new(WITH_THE_KEYBOARD)
    finder = Keyboardio2mqtt::KeyboardFinder.new(configuration: Keyboardio2mqtt::Configuration.new,
                                                 shell: shell, ports: StandInPorts.new(PORT))
    finder.attached_keyboards

    shell.says(WITHOUT_THE_KEYBOARD)

    assert_empty finder.attached_keyboards
  end

  def test_a_machine_that_cannot_be_asked_about_its_usb_devices_reports_no_keyboards
    finder = Keyboardio2mqtt::KeyboardFinder.new(configuration: Keyboardio2mqtt::Configuration.new,
                                                 shell: StandInShell.new("", success: false),
                                                 ports: StandInPorts.new(PORT))

    assert_empty finder.attached_keyboards
  end

  private

  def finding(usb_tree, configuration: Keyboardio2mqtt::Configuration.new, ports: StandInPorts.new(PORT))
    Keyboardio2mqtt::KeyboardFinder.new(configuration: configuration,
                                        shell: StandInShell.new(usb_tree), ports: ports)
  end
end
