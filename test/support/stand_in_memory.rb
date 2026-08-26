# Stands in for the memory of what the availability light was last asked for,
# without touching the disk.
class StandInMemory
  def initialize(remembered = {})
    @remembered = remembered
    @last_seen = {}
  end

  def seen(keyboard_identity, at)
    @last_seen[keyboard_identity] = at
  end

  def known
    @last_seen.dup
  end

  def forget(keyboard_identity)
    @remembered.delete(keyboard_identity)
    @last_seen.delete(keyboard_identity)
  end

  def for(keyboard_identity, light_name)
    @remembered.dig(keyboard_identity, light_name)
  end

  def remember(keyboard_identity, light_name, asked)
    (@remembered[keyboard_identity] ||= {})[light_name] = asked
  end
end
