require "minitest/autorun"
require "keyboardio2mqtt"

Dir[File.expand_path("support/*.rb", __dir__)].sort.each { |stand_in| require stand_in }
