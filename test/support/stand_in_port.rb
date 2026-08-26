# Stands in for the keyboard's serial port, remembering every command line it was
# asked to send.
class StandInPort
  attr_reader :written

  def initialize
    @written = []
  end

  def write(command_line)
    @written << command_line

    true
  end
end
