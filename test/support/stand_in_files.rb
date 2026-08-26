# Stands in for opening the keyboard's port, so tests can see that it is opened
# for one command at a time and closed again straight away.
class StandInFiles
  attr_reader :times_opened

  def initialize(held_by_somebody_else: false)
    @held_by_somebody_else = held_by_somebody_else
    @times_opened = 0
    @opened = []
  end

  def open(_path, _mode)
    raise Errno::EBUSY if @held_by_somebody_else

    @times_opened += 1
    port = StandInFile.new
    @opened << port
    yield port
    port.close
  end

  def written
    @opened.flat_map(&:written)
  end

  def all_closed?
    @opened.all?(&:closed?)
  end

  def all_replies_read?
    @opened.all?(&:reply_read?)
  end
end

# Stands in for the port once it is open. It answers a command the way the
# keyboard does: one line holding a single full stop.
class StandInFile
  attr_reader :written

  def initialize
    @written = []
    @reply = [ ".\n" ]
    @closed = false
  end

  def puts(command_line)
    @written << command_line
  end

  def gets
    @reply.shift
  end

  def close
    @closed = true
  end

  def closed?
    @closed
  end

  def reply_read?
    @reply.empty?
  end
end
