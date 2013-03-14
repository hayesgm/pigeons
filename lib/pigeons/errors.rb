module Pigeons
  
  module PigeonError
    class PigeonConfigError < StandardError; end
    class PigeonFlightConfigError < PigeonConfigError; end
  end

end