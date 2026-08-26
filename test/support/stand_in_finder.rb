# Stands in for the keyboard finder, answering which keyboards are plugged in
# right now.
class StandInFinder
  def initialize(*keyboards)
    @keyboards = keyboards
  end

  def attached_keyboards
    @keyboards.dup
  end
end
