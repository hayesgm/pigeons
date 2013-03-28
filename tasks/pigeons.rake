
namespace :pigeons do

  desc "Show all posts that would be immediately sent"
  task :check, [ :debug ] => :environment do |t, args|
    p [ 'Pigeons::', 'Rake::Pigeons::Check', 'Initiating', args ]
    
    flights = Pigeons.assemble(send: false, debug: args[:debug] == "true")

    flights.each do |flight, letters|
      puts "\n#{flight.titleize} Flight"

      letters.each do |letter_info|
        puts "\t#{letter_info[:letter].titleize} -> #{letter_info[:count]} #{letter_info[:entity]}"
      end
    end
    
    p [ 'Pigeons::', 'Rake::Pigeons::Check', 'Completed' ]
  end

  # Arguments
  # Days:: Number of days to run simulation
  # Debug:: Should we print extensive debug information?
  # Send:: If 'yes' will truly deliver letters, otherwise don't send letters.  Alt: set send = <action_name> and only that letter will be sent
  # Force:: Force simulation to run in production environment
  desc "Run a simulation by day of Pigeon letters to be sent."
  task :flight_test, [ :days, :debug, :force, :send ] => :environment do |t, args|
    unless Rails.env.staging? || Rails.env.development? || Rails.env.test? # Note, due to mocks, etc. this is not considered safe to run on any environment besides develpoment and staging
      unless args[:force].blank?
        puts "\n\e[0;31m   ######################################################################" 
        puts "   #\n   #       Are you REALLY sure you want to run  Flight Test in #{Rails.env.capitalize}?"
        puts "   #\n   #       Nothing should affect the database- but this is not considered safe for production databases."
        puts "   #\n   #       Specifically, we are going to override Time.now, Time.current (with monkeypatches) and run a"
        puts "   #\n   #       actual simulation day-by-day that we will rollback (and hope doesn't actually send letters)."
        puts "   #\n   #       These assumptions are nice, but not good in a production environment."
        puts "   #\n   #               Enter y/N + enter to continue\n   #"
        puts "   ######################################################################\e[0m\n" 
        proceed = STDIN.gets[0..0] rescue nil 
        exit unless proceed == 'y' || proceed == 'Y'
      else
        raise "Refusing to run Flight Test on anything but Development and Staging (try rake pigeons:flight_test[days,debug,*force,send])"
      end
    end

    p [ 'Pigeons::', 'Rake::Pigeons::FlightTest', 'Initiating', args ]
    days = args[:days] ? args[:days].to_i : 15 # Default to 15 days?
    debug = args[:debug] || false
    send = args[:send]

    # Stub both Time.now and Time.current
    reality = Time.now
    current_reality = Time.current

    results = {} # E.g. { 'aflight': [ { letter_a: 5 } ]}
    benchmarks = [] # day => run_time

    # TODO: I'd like to be able to do this without degrading the environment with stubs, but that's probably not going to happen
    time_class = class << ::Time; self; end
    pigeon_class = class << ::PigeonMailer; self; end

    # Allow sending of letters during simulation

    unless %w(true t yes y 1).include?(send)
      PigeonMailer.action_methods.each { |mailer_action| pigeon_class.send(:define_method, mailer_action) { |*args| return true } unless mailer_action == send }
    end

    PigeonLetter.transaction do
      begin
        days.times do |day|
          puts ''
          puts '-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-'
          puts "Pigeons:: Simulating Day ##{day+1}"
          puts ''
          puts 'Letters by Type [Totals]'
          PigeonLetter.where("sent_at IS NOT NULL").to_a.group_by { |pl| pl.letter_type }.each { |letter_type, letters| puts "\t#{letter_type}: #{letters.count}" }
          puts ''
          puts ''

          # Time is a social construct
          # We'll adjust it as need be
          time_class.send(:define_method, :now) { reality + day.days }
          time_class.send(:define_method, :current) { current_reality + day.days }
          
          start_time = Time.new.to_f
          flights = Pigeons.assemble(send: true, debug: debug)
          benchmarks[day] = Time.new.to_f - start_time

          flights.each do |flight, letters|
            results[flight] ||= {}
            
            puts "\n#{flight.titleize} Flight"

            letters.each do |letter_info|
              results[flight][letter_info[:letter]] ||= []
              results[flight][letter_info[:letter]][day] = ( results[flight][letter_info[:letter]][day] || 0 ) + letter_info[:count]
              puts "\t#{letter_info[:letter].titleize} -> #{letter_info[:count]} #{letter_info[:entity]}"
            end
          end
        end
      rescue => e
        p [ 'Pigeons::', 'Encountered error in Rake::Pigeons::FlightTest', e.inspect ]
        puts e.backtrace.join("\n\t")
      ensure
        p [ 'Pigeons::', 'Rolling back any changes made during test flight...' ]
        raise ActiveRecord::Rollback # Force a rollback-- we don't want anything to be real here.  In the words of Biggie, "It was all a dream..."
      end
    end

    p [ 'Pigeons::', 'Flight Test Results' ]
    p [ 'Pigeons::' 'Raw Results', results ]
    p [ 'Pigeons::' 'Runtimes', benchmarks ]

    padding = proc { |num, i| " " + num.to_s + ( 1..(i.to_s.length - 1 + 2*3 - num.to_s.length) ).map { " " }.join }

    results.each do |flight, day_by_day|
      puts '##############################'
      puts "#     #{flight.capitalize} Flight        #"
      puts '##############################'
      puts ""
      puts ""

      # "                    "
      # Get the length just right
      leading = ( 1..(day_by_day.map { |letter, count_by_day| letter }.sort { |a,b| a.length <=> b.length }.last.length + 2) ).map { " " }.join


      puts "#{leading}| Day #{ (1..days).map { |i| "#{i}      " }.join }"
      day_by_day.each do |letter, count_by_day|
        puts ""
        puts "#{letter}#{ ( leading.length - letter.length ).times.map { " " }.join }|     #{ count_by_day.each_with_index.map { |count, i| padding.call(count, i+1) }.join }"
      end
    end
          
    p [ 'Pigeons::', 'Rake::Pigeons::FlightTest', 'Completed' ]
  end

  task :send, [] => :environment do |t, args|
    p [ 'Pigeons::', 'Rake::Pigeons::Send', 'Initiating', args ]
    
    flights = Pigeons.assemble(send: true)
    
    flights.each do |flight, letters|
      puts "\n#{flight.titleize} Flight"

      letters.each do |letter_info|
        puts "\t#{letter_info[:letter].titleize} -> #{letter_info[:count]} #{letter_info[:entity]}"
      end
    end
    
    p [ 'Pigeons::', 'Rake::Pigeons::Send', 'Completed' ]
  end

end
