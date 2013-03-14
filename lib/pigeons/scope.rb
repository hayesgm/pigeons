module Pigeons

  module Scope

    def self.get_scope(args)
      elements = args[:elements]
      previous_base_scope = args[:previous_base_scope]
      previous_letters = args[:previous_letters]
      flights = args[:flights]
      flight = args[:flight]
      letter_info = args[:letter_info]
      flight_id = args[:flight_id]
      opts = args[:opts]

      Pigeons::Logger.debug [ 'Pigeons::', 'Scope::GetScope', 'Elements', elements ] if opts[:debug]

      # We accept a running base_element
      # -- gets
      # then gets
      # then gets

      base_scope = previous_base_scope unless previous_base_scope.nil?

      if elements[:base_element] # E.g. "users..."
        base_scope = get_base_scope(elements[:base_element])
        previous_letters = [] unless elements[:joiner] # Unless we have a joiner, we're ignoring previous letters
      elsif elements[:joiner].nil? # "then..."
        # must start with a base element or a joiner
        raise PigeonError::PigeonFlightConfigError, "Missing a joiner in #{flight}, start a line with an elements (e.g. user) or and/then: #{letter_info}"
      end

      Pigeons::Logger.debug [ 'Pigeons::', 'Scope::GetScope', 'Base Element Count', "#{base_scope.name.number(base_scope.count)}" ] if opts[:debug]

      raise PigeonError::PigeonFlightConfigError, "First flight element in #{flight} must specify base (e.g. user), but didn't: #{letter_info}" if base_scope.nil?

      scope = base_scope.scoped # We'll start with a fresh
      source_arel = scope.arel_table # This will be used for checking PigeonLetters.. or posts
      pigeon_arel = PigeonLetter.arel_table # used in queries below

      # First, we'll check by flight
      # Flights are essentially cohorts
      # All entites belong to one based on entity_id%x=y where x is the number of flights
      # and y is the order of this flight in alphabetically order starting with 0
      if flights.count > 0
        scope = scope.where(["id%?=?",flights.count,flight_id])
      end

      raise PigeonError::PigeonFlightConfigError, "Flight #{flight} must specify letter: #{letter_info}" if elements[:letter].nil?

      # Convert the letter to snakecase
      letter = elements[:letter].downcase.gsub(' ', '_') # "a ... letter"

      # Make sure this letter is valid
      raise PigeonError::PigeonFlightConfigError, "Flight #{flight} referenced letter \"#{letter}\" that doesn't exist in PigeonMailer.  Try adding \"def #{letter}(#{source_arel.name.singularize})\"" unless PigeonMailer.action_methods.include?(letter.to_s) || PigeonMailer.respond_to?(letter.to_s) # We'll take action_methods or respond_to?

      # Next, we need to do the "based on letters" queries

      # Todo/Question: what happens when a user switches cohorts and now deserves two item types
      # we need to be mighty cautious here to preclude that
      # Also, may happen with milestones
      # TODO: This above, last big thing besides getting these queries right
      # and renaming maybe from letters to posts, or not
      # also, what are we actually sending

      # First, we'll base it on cooldown
      # Since we don't ever want to send an entity two letters on the same day
      scope = Checks.no_recent_letter_check(scope: scope, source: source_arel, pigeon: pigeon_arel)

      # If we have a time_metric, we'll track a relative time
      # This will be used for "every" and "after that"
      # Note: we default coeffecient to 1 for the case "Every day"
      relative_time = nil # base

      if elements[:time_metric] # "24 hours..."
        relative_time = case elements[:time_metric_unit]
        when "second", "minute", "hour", "day", "week", "fortnight", "month", "year"
          (elements[:time_metric_coefficient] || 1).to_i.send(elements[:time_metric_unit]).ago
        when "time"
          Time.now # "Every time" = since now
        else
          raise PigeonError::PigeonFlightConfigError, "Flight #{flight} referenced invalid time unit (e.g. days, hours, ..): #{elements[:time_metric_unit]}: #{letter_info}"
        end
      end

      # Then, we'll base it on ourselves
      # Select all items where not exists letter = self (unless recurring, then base on time)
      if elements[:recurring].blank? # every
        scope = Checks.non_recurring_check(scope: scope, source: source_arel, pigeon: pigeon_arel, letter: letter)
      else # Recurring ("every")
        scope = Checks.recurring_check(scope: scope, source: source_arel, pigeon: pigeon_arel, letter: letter, relative_time: relative_time)
      end

      # Next, we're going to check the previous req clause
      if elements[:relative] || ( elements[:joiner] == "then" )# "after..." or begins with "then..."

        # TODO: Type may also be a milestone or item metric
        # Need to make this much more diverse
        relative_action = nil
        time_item = nil # TODO: Event

        relative_time = Time.now if relative_time.nil? # If we don't have a relative time, we count it against now

        # Then, we need to check our relative
        if elements[:relative]
          case elements[:relative]
          when "after"
            relative_action = :after
            time_item = elements[:time_item]
          else
            raise PigeonError::PigeonFlightConfigError, "Flight #{flight} referenced invalid time relative (e.g. before/after): #{elements[:relative]}: #{letter_info}"
          end
        else # joiner - if we don't have a relative, we'll default to "after that"
          case elements[:joiner]
          when "then"
            relative_action = :after
            time_item = "that"
          else
            raise PigeonError::PigeonFlightConfigError, "Flight #{flight} got to illegal area of code: #{letter_info}"
          end
        end

        # Then, we need to find the relative letter type
        if time_item == "that" # Compare with last letter -- this is baked in
          raise PigeonError::PigeonFlightConfigError, "Flight #{flight} referenced to previous letters (\"#{elements[:time_metric]} #{elements[:relative]}\"), but ambiguous previous lines: #{letter_info}" if previous_letters.empty?
          scope = Checks.after_letter_check( scope: scope, source: source_arel, pigeon: pigeon_arel, letters: previous_letters.clone, relative_action: relative_action, relative_time: relative_time )
        elsif time_item =~ /^(sign((ing )|[-]|[ ])?up)|(creat(e|ion))$/i # this is also baked in (matches: signup, signing up, sign up, sign-up, create, creation)
          scope = scope.where("created_at < ?", relative_time)
        else
          # Let's try to match this against the events given to settings
          matched_events = Settings.events.select do |event|
            match = event[:matcher].match(time_item)
            if match
              # TODO # uhh
              scope = event[:clause].call(scope, relative_time, match)
              true
            else
              false
            end
          end

          raise PigeonError::PigeonFlightConfigError, "Flight #{flight} has unmatched event: \"#{time_item}\".  You must set an extension to match all events: #{letter_info}" if matched_events.count == 0
        end

      end

      # Last, we'll check conditionals brought on by us
      if elements[:conditionals] # "who've..."
        matched_conditionals = Settings.conditionals.select do |conditional|
          match = conditional[:matcher].match(elements[:conditionals])
          if match
            scope = conditional[:clause].call(scope, match)
            true
          else
            false
          end
        end
        raise PigeonError::PigeonFlightConfigError, "Flight #{flight} has unmatched conditional: \"#{elements[:conditionals]}\".  You must set an extension to match all conditionals: #{letter_info}" if matched_conditionals.count == 0
      end

      # Set previous letters
      if elements[:base_element].nil? && !elements[:joiner].nil? && !elements[:conditionals].nil?
        # then who've ...    
        previous_letters << letter # we're going to append ourselves to previous letters to allow us to skip since we've kept a running base element, but added conditions that make us skippable
      else
        # otherwise, to continue on, you must have received this specific letter
        previous_letters = [ letter ] # just us
      end

      return {
        scope: scope,
        base_scope: base_scope,
        letter: letter,
        previous_letters: previous_letters,
        entity: source_arel.name }
    end

    # This function takes a base element like "user" and returns a scope
    def self.get_base_scope(base_element)
      # First, we'll check the bases defined
      Settings.bases.each do |base|
        match = base[:matcher].match(base_element)
        if match
          res = base[:clause].call(match)

          if !res.is_a?(ActiveRecord::Relation)
            raise PigeonError::PigeonConfigError, "Base scope must return an ActiveRecord::Relation, but got #{res.class.name} for #{base_element}"
          end

          return res
        end
      end

      # Then, we'll check for a model named likeso
      # TODO/Note, we may want to depluralize
      klass = Object.const_get(base_element.gsub(' ','_').classify) rescue nil

      if klass && ( klass < ActiveRecord::Base )
        return klass.scoped
      end

      raise PigeonError::PigeonConfigError, "Unable to find a scope for base element: #{base_element}"
    end

  end
end