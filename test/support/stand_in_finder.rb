# Stands in for the keyboard finder, answering which keyboards are plugged in
# right now.
class StandInFinder
  def initialize(*keyboards)
    @keyboards = keyboards
  end

  def attached_keyboards
    @keyboards.dup
  end

  def unplug(identity)
    @keyboards.reject! { |keyboard| keyboard.identity == identity }
  end

  def plug_in(keyboard)
    @keyboards << keyboard
  end
end
