module Keyboardio2mqtt
  # The keyboard's serial port, held only for as long as one command takes.
  #
  # The port is exclusive: Chrysalis holds it whenever it is open, and a port
  # somebody else is holding must not stop the daemon. So it is opened, written
  # to once, drained and closed again, and a port that cannot be had is reported
  # as a command that did not land.
  #
  # Nothing here sets the line speed, and nothing should: opening a board's port
  # at 1200 baud is how it is told to reboot into the firmware flasher.
  class FocusPort
    READ_AND_WRITE = "r+".freeze
    DONE = ".".freeze

    def initialize(path, files: File)
      @path = path
      @files = files
    end

    def write(command_line)
      @files.open(@path, READ_AND_WRITE) do |port|
        port.puts(command_line)
        drain(port)
      end

      true
    rescue SystemCallError => error
      Keyboardio2mqtt.logger.warn("could not reach the keyboard on #{@path}: #{error.message}")
      false
    end

    private

    # The keyboard answers a command with a line holding a single full stop.
    # Reading it leaves nothing behind for the next command to trip over.
    def drain(port)
      while (line = port.gets)
        break if line.strip == DONE
      end
    end
  end
end
