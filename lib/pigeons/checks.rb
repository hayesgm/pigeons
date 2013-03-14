module Pigeons

  module Checks

    # We're going to try to factor all major queries into individual functions
    def self.no_recent_letter_check(args)
      scope = args[:scope]
      pigeon_arel = args[:pigeon]
      source_arel = args[:source]

      scope.where(
        PigeonLetter.where(
          pigeon_arel[:cargo_id].eq(source_arel[:id]).and(
            pigeon_arel[:cargo_type].eq(source_arel.name.classify)
          ).and(
            pigeon_arel[:created_at].gt(Pigeons::Settings.cooldown.ago)
          )
        ).exists.not
      )
    end

    def self.non_recurring_check(args)
      scope = args[:scope]
      pigeon_arel = args[:pigeon]
      source_arel = args[:source]
      letter = args[:letter]

      scope.where(
        PigeonLetter.where(
          pigeon_arel[:cargo_id].eq(source_arel[:id]).and(
            pigeon_arel[:cargo_type].eq(source_arel.name.classify)
          ).and(
            pigeon_arel[:created_at].not_eq(nil)
          ).and(
            pigeon_arel[:letter_type].eq(letter)
          )
        ).exists.not
      )
    end

    def self.recurring_check(args)
      scope = args[:scope]
      pigeon_arel = args[:pigeon]
      source_arel = args[:source]
      letter = args[:letter]
      relative_time = args[:relative_time]

      scope.where(
        PigeonLetter.where(
          pigeon_arel[:cargo_id].eq(source_arel[:id]).and(
            pigeon_arel[:cargo_type].eq(source_arel.name.classify)
          ).and(
            pigeon_arel[:created_at].gt(relative_time)
          ).and(
            pigeon_arel[:letter_type].eq(letter)
          )
        ).exists.not
      )
    end

    def self.after_letter_check(args)
      scope = args[:scope]
      pigeon_arel = args[:pigeon]
      source_arel = args[:source]
      letters = args[:letters]
      relative_action = args[:relative_action]
      relative_time = args[:relative_time]

      # TODO: We really need to sit down and think about what this check means
      # Right now, it's going to mean
      # All letters of letters type must have been made after relative_time ago
      # And there must exist a letter of some such type
      # As in, "we need the existence of a letter of type X or Y, and no letter of type X or Y may have been sent in the last .. days"

      scope.where(
        PigeonLetter.where(
          pigeon_arel[:cargo_id].eq(source_arel[:id]).and(
            pigeon_arel[:cargo_type].eq(source_arel.name.classify)
          ).and(
            pigeon_arel[:letter_type].in(letters)
          )
        ).exists
      ).where(
        PigeonLetter.where(
          pigeon_arel[:cargo_id].eq(source_arel[:id]).and(
            pigeon_arel[:cargo_type].eq(source_arel.name.classify)
          ).and(
            pigeon_arel[:letter_type].in(letters)
          ).and(
            relative_action == :after ?
              pigeon_arel[:created_at].gt(relative_time) : nil # TODO: nil?
          )
        ).exists.not
      )
    end

  end
end