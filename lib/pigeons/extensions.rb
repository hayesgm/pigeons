module Pigeons

  # Extensions will tell Pigeon how to parse flights for app-specific context
  class Extension
    # base /regexp/ { return scope }

    protected

      def self.base(matcher, &clause)
        matcher = Regexp.new(matcher, "i") if matcher.is_a?(String)
        raise ArgumentError, "First argument must be a string or regular expression" unless matcher.is_a?(Regexp)
        raise ArgumentError, "Must include block which returns scope" unless block_given?

        Pigeons.add_base(matcher, clause)
      end

      def self.condition(matcher, &clause)
        matcher = Regexp.new(matcher, "i") if matcher.is_a?(String)
        raise ArgumentError, "First argument must be a string or regular expression" unless matcher.is_a?(Regexp)
        raise ArgumentError, "Must include block which returns scope" unless block_given?

        Pigeons.add_conditional(matcher, clause)
      end

      def self.event(matcher, &clause)
        matcher = Regep.new(matcher, "i") if matcher.is_a?(String)
        raise ArgumentError, "First argument must be a string or regular expression" unless matcher.is_a?(Regexp)
        raise ArgumentError, "Must include block which returns scope" unless block_given?

        Pigeons.add_event(matcher, clause)
      end

  end
end