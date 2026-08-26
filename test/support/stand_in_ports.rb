# Stands in for the /dev directory, answering which serial ports are there and
# remembering what it was asked about.
class StandInPorts
  attr_reader :asked_for

  def initialize(*there)
    @there = there
    @asked_for = []
  end

  def glob(pattern)
    @asked_for << pattern

    @there.select { |port| File.fnmatch(pattern, port) }
  end
end
