require File.expand_path('../test_helper', __FILE__)
require 'test/unit'
require 'shoulda'
require 'mocha'

# To test:
# 1) Bases (check)
# 2) Conditions
# 3) Flights (Cohorts)
# 4) Bit more complexity?
# 5) Send
# 6) "signup", aye!

class PigeonExtensions < Pigeons::Extension

  # Match an ownership
  condition /^own \s+ (?<property>\w+)/ix do |scope, match|
    # p [ "Pigeon Extension::Condition", "#{item} matched conditional" ]

    scope.where([ "property LIKE ?", "%#{match[:property].singularize}%" ])
  end

  condition /eaten/i do |scope, match|
    scope.where(eaten: true)
  end

  condition /slept/i do |scope, match|
    scope.where(slept: true)
  end

  base /^(?<color>\w+) \s+ dragon[s]?$/ix do |match|
    Dragon.scoped.where(color: match[:color])
  end

  base /^the pixies$/i do |match|
    Pixie.scoped
  end

  event /^hatching$/ do |scope, time, match|
    scope.where("hatched_at < ?", time)
  end

  event /^defeating (?<orc_name>.*)$/ do |scope, time, match|

    source_arel = scope.arel_table
    battle_arel = Battle.arel_table
    orc_arel = Orc.arel_table
    
    scope.where(
      Battle.joins(:orc).where(
        # match to dragon
        battle_arel[:dragon_id].eq(source_arel[:id]).and(
          orc_arel[:name].eq(match[:orc_name])
        ).and(
          battle_arel[:created_at].lt(time)
        ).and(
          battle_arel[:is_dragon_victor].eq(true)
        )
      ).exists
    )
  end

  event /^leveling up$/ do |scope, time, match|

    source_arel = scope.arel_table
    level_arel = Level.arel_table

    scope.where(
      Level.where(
        level_arel[:pixie_id].eq(source_arel[:id]).and(
          level_arel[:created_at].lt(time)
        )
      ).exists
    )
  end

end

class TestPigeons < Test::Unit::TestCase
  include Mocha

  context "when the config has issues" do
    should "raise unknown letter type" do
      Pigeons::Settings.pigeon_config_file = "ignored"
      File.stubs(:exists? => true)
      
      # Nonexistant
      PigeonMailer.stubs(respond_to?: false)
      File.stubs(:read => { flights: { aflight: [ "dragon gets a nonexistent letter" ] } }.to_json)

      assert_raise Pigeons::PigeonError::PigeonFlightConfigError do
        Pigeons.assemble
      end

      # No idea what class
      PigeonMailer.stubs(respond_to?: true)
      File.stubs(:read => { flights: { aflight: [ "rhinos gets a welcome letter" ] } }.to_json)
    end
  end

  # These test flights will get run and we'll check the resultant SQL
  # These are, obstensibly end-to-end tests
  test_flights = [
    # Test basic letter
    {
      name: "all dragons get welcome",
      config: { flights: { aflight: [ "dragons gets a welcome letter" ] } },
      # Simply a check to make sure we didn't send this letter type
      expected: [ letter_not_exists(simple_scope(Dragon.scoped), "welcome") ]
    },
    # Test a different base
    {
      name: "all orcs get goodbye",
      config: { flights: { aflight: [ "orcs get a goodbye letter" ] } },
      expected: [ letter_not_exists(simple_scope(Orc.scoped), "goodbye") ]
    },
    # Test relative time (after hours)
    {
      name: "all dragons get welcome after signup, hours",
      config: { flights: { aflight: [ "dragons gets a welcome letter 24 hours after signup" ] } },
      expected: [ letter_not_exists(simple_scope(Dragon.scoped), "welcome").where("created_at < ?", 24.hours.ago) ]
    },
    # Test relative time (after days)
    {
      name: "all dragons get welcome after signup, days",
      config: { flights: { aflight: [ "dragons gets a welcome letter 2 days after signup" ] } },
      expected: [ letter_not_exists(simple_scope(Dragon.scoped), "welcome").where("created_at < ?", 2.days.ago) ]
    },
    # Test recurring (every)
    {
      name: "all dragons get welcome after signup every weeks",
      config: { flights: { aflight: [ "dragons get a welcome letter every 3 weeks after signup" ] } },
      expected: [ simple_scope(Dragon.scoped).where(
          PigeonLetter.where(
            PigeonLetter.arel_table[:cargo_id].eq(Dragon.arel_table[:id]).and(
              PigeonLetter.arel_table[:cargo_type].eq(Dragon.arel_table.name.classify)
            ).and(
              PigeonLetter.arel_table[:created_at].gt(3.weeks.ago)
            ).and(
              PigeonLetter.arel_table[:letter_type].eq("welcome")
            )
          ).exists.not
        ).where("created_at < ?", 3.weeks.ago) ]
    },
    # Now, let's try an after
    {
      name: "all dragons get welcomed then fired",
      config: { flights: { aflight: [ "dragons get a welcome letter 2 seconds after signup",
                                      "then get a fired letter 2 hours after that" ] } },
      expected: [ letter_not_exists(simple_scope(Dragon.scoped), "welcome").where("created_at < ?", 2.seconds.ago),
                  letter_not_exists(simple_scope(Dragon.scoped), "fired").where(
                    PigeonLetter.where(
                      PigeonLetter.arel_table[:cargo_id].eq(Dragon.arel_table[:id]).and(
                        PigeonLetter.arel_table[:cargo_type].eq(Dragon.arel_table.name.classify)
                      ).and(
                        PigeonLetter.arel_table[:letter_type].in(["welcome"])
                      )
                    ).exists
                  ).where(
                    PigeonLetter.where(
                      PigeonLetter.arel_table[:cargo_id].eq(Dragon.arel_table[:id]).and(
                        PigeonLetter.arel_table[:cargo_type].eq(Dragon.arel_table.name.classify)
                      ).and(
                        PigeonLetter.arel_table[:letter_type].in(["welcome"])
                      ).and(
                        PigeonLetter.arel_table[:created_at].gt(2.hours.ago)
                      )
                    ).exists.not
                  )
                ]
    },
    # Let's add a condition
    {
      name: "all dragons who own lairs get taxed",
      config: { flights: { aflight: [ "dragons who own lairs get a tax letter every year" ] } },
      expected: [ simple_scope(Dragon.scoped).where(
                    PigeonLetter.where(
                      PigeonLetter.arel_table[:cargo_id].eq(Dragon.arel_table[:id]).and(
                        PigeonLetter.arel_table[:cargo_type].eq(Dragon.arel_table.name.classify)
                      ).and(
                        PigeonLetter.arel_table[:created_at].gt(1.year.ago)
                      ).and(
                        PigeonLetter.arel_table[:letter_type].eq("tax")
                      )
                    ).exists.not
                  ).where("property LIKE '%lair%'") ]
    },
    # Let's add a simple base
    {
      name: "all pixies",
      config: { flights: { aflight: [ "the pixies get a punk rock letter" ] } },
      expected: [ letter_not_exists(simple_scope(Pixie.scoped), "punk_rock") ]
    },
    # Let's add a complex base
    {
      name: "red dragon sadness",
      config: { flights: { aflight: [ "red dragons get a hate letter every day after signup" ] } },
      expected: [ simple_scope(Dragon.scoped.where(color: 'red')).where(
                  PigeonLetter.where(
                      PigeonLetter.arel_table[:cargo_id].eq(Dragon.arel_table[:id]).and(
                        PigeonLetter.arel_table[:cargo_type].eq(Dragon.arel_table.name.classify)
                      ).and(
                        PigeonLetter.arel_table[:created_at].gt(1.day.ago)
                      ).and(
                        PigeonLetter.arel_table[:letter_type].eq("hate")
                      )
                    ).exists.not
                  ).where(["created_at < ?", 1.day.ago]) ]
    },
    # Now let's test complex running conditions
    {
      name: "running conditions",
      config: { flights: { aflight: [ "dragons get a hello letter after signup",
                                     "then who've eaten get a food letter 1 hour after that",
                                     "then who've slept get a sleep letter after that",
                                     "then get a goodnight letter 30 minutes after that",
                                     "then gets a nightcap letter" ] } }, # Note, these running conditions are complicated
      expected: [ letter_not_exists(simple_scope(Dragon.scoped), "hello").where("created_at < ?", Time.now),
                  letter_not_exists(simple_scope(Dragon.scoped).where(eaten: true), "food").where(
                    PigeonLetter.where(
                      PigeonLetter.arel_table[:cargo_id].eq(Dragon.arel_table[:id]).and(
                        PigeonLetter.arel_table[:cargo_type].eq(Dragon.arel_table.name.classify)
                      ).and(
                        PigeonLetter.arel_table[:letter_type].in(["hello"])
                      )
                    ).exists
                  ).where(
                    PigeonLetter.where(
                      PigeonLetter.arel_table[:cargo_id].eq(Dragon.arel_table[:id]).and(
                        PigeonLetter.arel_table[:cargo_type].eq(Dragon.arel_table.name.classify)
                      ).and(
                        PigeonLetter.arel_table[:letter_type].in(["hello"])
                      ).and(
                        PigeonLetter.arel_table[:created_at].gt(1.hour.ago)
                      )
                    ).exists.not
                  ),
                  letter_not_exists(simple_scope(Dragon.scoped).where(slept: true), "sleep").where(
                    PigeonLetter.where(
                      PigeonLetter.arel_table[:cargo_id].eq(Dragon.arel_table[:id]).and(
                        PigeonLetter.arel_table[:cargo_type].eq(Dragon.arel_table.name.classify)
                      ).and(
                        PigeonLetter.arel_table[:letter_type].in(["hello","food"])
                      )
                    ).exists
                  ).where(
                    PigeonLetter.where(
                      PigeonLetter.arel_table[:cargo_id].eq(Dragon.arel_table[:id]).and(
                        PigeonLetter.arel_table[:cargo_type].eq(Dragon.arel_table.name.classify)
                      ).and(
                        PigeonLetter.arel_table[:letter_type].in(["hello","food"])
                      ).and(
                        PigeonLetter.arel_table[:created_at].gt(Time.now)
                      )
                    ).exists.not
                  ),
                  letter_not_exists(simple_scope(Dragon.scoped), "goodnight").where(
                    PigeonLetter.where(
                      PigeonLetter.arel_table[:cargo_id].eq(Dragon.arel_table[:id]).and(
                        PigeonLetter.arel_table[:cargo_type].eq(Dragon.arel_table.name.classify)
                      ).and(
                        PigeonLetter.arel_table[:letter_type].in(["hello","food","sleep"])
                      )
                    ).exists
                  ).where(
                    PigeonLetter.where(
                      PigeonLetter.arel_table[:cargo_id].eq(Dragon.arel_table[:id]).and(
                        PigeonLetter.arel_table[:cargo_type].eq(Dragon.arel_table.name.classify)
                      ).and(
                        PigeonLetter.arel_table[:letter_type].in(["hello","food","sleep"])
                      ).and(
                        PigeonLetter.arel_table[:created_at].gt(30.minutes.ago)
                      )
                    ).exists.not
                  ),
                  letter_not_exists(simple_scope(Dragon.scoped), "nightcap").where(
                     PigeonLetter.where(
                      PigeonLetter.arel_table[:cargo_id].eq(Dragon.arel_table[:id]).and(
                        PigeonLetter.arel_table[:cargo_type].eq(Dragon.arel_table.name.classify)
                      ).and(
                        PigeonLetter.arel_table[:letter_type].in(["goodnight"])
                      )
                    ).exists
                  ).where(
                    PigeonLetter.where(
                      PigeonLetter.arel_table[:cargo_id].eq(Dragon.arel_table[:id]).and(
                        PigeonLetter.arel_table[:cargo_type].eq(Dragon.arel_table.name.classify)
                      ).and(
                        PigeonLetter.arel_table[:letter_type].in(["goodnight"])
                      ).and(
                        PigeonLetter.arel_table[:created_at].gt(Time.now)
                      )
                    ).exists.not
                  ) ]
    },
    # Finally, we're going to test events
    # First, simply
    {
      name: "all dragons get a birth certificate letter after hatching",
      config: { flights: { aflight: [ "all dragons get a birth certificate letter after hatching" ] } },
      expected: [ letter_not_exists(simple_scope(Dragon.scoped), "birth_certificate").where("hatched_at < ?", Time.now) ]
    },
    # Now, we're test a more complex event
    {
      name: "all dragons get a congratulations letter after defeating Hodor.",
      config: { flights: { aflight: [ "all dragons get a congratulations letter after defeating Hodor." ] } },
      expected: [ letter_not_exists(simple_scope(Dragon.scoped), "congratulations").where(
        Battle.joins(:orc).where(
          Battle.arel_table[:dragon_id].eq(Dragon.arel_table[:id]).and(
            Orc.arel_table[:name].eq("Hodor")
          ).and(
            Battle.arel_table[:created_at].lt(Time.now)
          ).and(
            Battle.arel_table[:is_dragon_victor].eq(true)
          )
        ).exists
      ) ]
    },
    # A recurring event
    {
      name: "pixies getting a level up email",
      config: { flights: { aflight: [ "pixies get a level up letter every time after leveling up" ] } },
      expected: [ simple_scope(Pixie.scoped).where(
          PigeonLetter.where(
            PigeonLetter.arel_table[:cargo_id].eq(Pixie.arel_table[:id]).and(
              PigeonLetter.arel_table[:cargo_type].eq(Pixie.arel_table.name.classify)
            ).and(
              PigeonLetter.arel_table[:created_at].gt(Time.now)
            ).and(
              PigeonLetter.arel_table[:letter_type].eq("level_up")
            )
          ).exists.not
        ).where(
          Level.where(
            Level.arel_table[:pixie_id].eq(Pixie.arel_table[:id]).and(
              Level.arel_table[:created_at].lt(Time.now)
            )
          ).exists
        ) ]
    },
    # Finally, we're going to test base changes
    {
      name: "some dragons, but then other dragons",
      config: { flights: { aflight: [ "red dragons get a red letter",
                                      "then get a redder letter 1 hour after that",
                                      "blue dragons get a blue letter",
                                      "then get a bluer letter 1 fortnight" ] } },
      expected: [ letter_not_exists(simple_scope(Dragon.where(color: 'red')), "red"),
                  letter_not_exists(simple_scope(Dragon.where(color: 'red')), "redder").where(
                    PigeonLetter.where(
                      PigeonLetter.arel_table[:cargo_id].eq(Dragon.arel_table[:id]).and(
                        PigeonLetter.arel_table[:cargo_type].eq(Dragon.arel_table.name.classify)
                      ).and(
                        PigeonLetter.arel_table[:letter_type].in(["red"])
                      )
                    ).exists
                  ).where(
                    PigeonLetter.where(
                      PigeonLetter.arel_table[:cargo_id].eq(Dragon.arel_table[:id]).and(
                        PigeonLetter.arel_table[:cargo_type].eq(Dragon.arel_table.name.classify)
                      ).and(
                        PigeonLetter.arel_table[:letter_type].in(["red"])
                      ).and(
                        PigeonLetter.arel_table[:created_at].gt(1.hour.ago)
                      )
                    ).exists.not
                  ),
                  letter_not_exists(simple_scope(Dragon.where(color: 'blue')), "blue"),
                  letter_not_exists(simple_scope(Dragon.where(color: 'blue')), "bluer").where(
                    PigeonLetter.where(
                      PigeonLetter.arel_table[:cargo_id].eq(Dragon.arel_table[:id]).and(
                        PigeonLetter.arel_table[:cargo_type].eq(Dragon.arel_table.name.classify)
                      ).and(
                        PigeonLetter.arel_table[:letter_type].in(["blue"])
                      )
                    ).exists
                  ).where(
                    PigeonLetter.where(
                      PigeonLetter.arel_table[:cargo_id].eq(Dragon.arel_table[:id]).and(
                        PigeonLetter.arel_table[:cargo_type].eq(Dragon.arel_table.name.classify)
                      ).and(
                        PigeonLetter.arel_table[:letter_type].in(["blue"])
                      ).and(
                        PigeonLetter.arel_table[:created_at].gt(1.fortnight.ago)
                      )
                    ).exists.not
                  ) ]
    },
    # Next, we'll test two flights
    {
      name: "two flights - some dragons, but then other dragons",
      config: { flights: { aflight: [ "red dragons get a red letter" ], bflight: [ "red dragons get a blue letter" ] } },
      expected: {
        aflight: [ letter_not_exists(simple_scope(Dragon.where(color: 'red'),2,0), "red") ],
        bflight: [ letter_not_exists(simple_scope(Dragon.where(color: 'red'),2,1), "blue") ]
      }
    }
  ]

  context "in end-to-end test flights" do
    setup do
      Pigeons::Settings.pigeon_config_file = "ignored"
      File.stubs(:exists? => true)

      PigeonMailer.stubs(respond_to?: true)
      ::Time.stubs(now: ::NOW) # Make this static for a test
      ::Time.stubs(current: ::CURRENT)
    end
    puts test_flights.map { |flight| flight[:config][:flights][:aflight].join("\n") }.join("\n")

    test_flights.each do |flight_test|
      config = flight_test[:config]
      expected = flight_test[:expected]

      should "for #{flight_test[:name]}" do
        File.stubs(:read => config.to_json)
        flights = Pigeons.assemble
        if flights['bflight'].nil? # Test just one
          assert_same_elements expected.map { |e| e.to_sql }, flights['aflight'].map { |l| l[:scope].to_sql }
        else
          assert_same_elements expected[:aflight].map { |e| e.to_sql }, flights['aflight'].map { |l| l[:scope].to_sql }
          assert_same_elements expected[:bflight].map { |e| e.to_sql }, flights['bflight'].map { |l| l[:scope].to_sql }
        end
      end
    end
    
  end

end