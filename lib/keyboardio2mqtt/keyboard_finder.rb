module Keyboardio2mqtt
  # The only place that knows how a keyboard is found on this machine: macOS says
  # what is on the USB bus, and a Keyboardio's port is named after its serial
  # number.
  #
  # A keyboard is kept for as long as it stays plugged in, so it goes on
  # remembering the colour it is showing. One that goes away is dropped, and comes
  # back afresh.
  class KeyboardFinder
    VENDOR = 13462
    PRODUCT = 6
    WHAT_IT_IS = "Keyboardio Model 100".freeze

    ASK_THE_USB_BUS = %w[ioreg -p IOUSB -w0 -l].freeze
    EACH_DEVICE = "+-o ".freeze
    SERIAL_NUMBER = /"USB Serial Number" = "([^"]+)"/
    PORT_DIRECTORY = "/dev/cu.usbmodem".freeze

    def initialize(configuration:, shell: Open3, ports: Dir)
      @configuration = configuration
      @shell = shell
      @ports = ports
      @keyboards = {}
    end

    def attached_keyboards
      plugged_in = serial_numbers

      @keyboards.select! { |identity, _| plugged_in.include?(identity) }
      plugged_in.each { |identity| take_on(identity) }

      @keyboards.values
    end

    private

    def take_on(identity)
      return if @keyboards.key?(identity)

      port = port_for(identity)
      unless port
        Keyboardio2mqtt.logger.warn("the keyboard #{identity} has no port yet; trying again next time")
        return
      end

      @keyboards[identity] = Keyboard.new(identity: identity, port: FocusPort.new(port),
                                          name: @configuration.name_for(identity) || WHAT_IT_IS)
    end

    # The port is called usbmodem, then the keyboard's serial number, then a digit
    # for the interface, which is not ours to guess.
    def port_for(identity)
      @ports.glob("#{PORT_DIRECTORY}#{identity}*").first
    end

    def serial_numbers
      usb_tree.split(EACH_DEVICE).filter_map { |device| serial_number_of(device) }
    end

    def serial_number_of(device)
      return unless ours?(device)

      device[SERIAL_NUMBER, 1]
    end

    def ours?(device)
      device.include?(%("idVendor" = #{VENDOR})) && device.include?(%("idProduct" = #{PRODUCT}))
    end

    def usb_tree
      said, status = @shell.capture2(*ASK_THE_USB_BUS)
      return said if status.success?

      Keyboardio2mqtt.logger.warn("this machine would not say what is on its USB bus")
      ""
    end
  end
end
