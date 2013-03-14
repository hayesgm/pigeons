
# Pigeon controls the Carrier Pigeon system
# Note, we're going to try to make this not require Rails - but it may require some aspects of ActiveSupport, etc.

module Pigeons

  class Settings
    # Initialize class attributes
    class_attribute :pigeon_config_file
    class_attribute :cooldown # Limit time between sending entity a second letter
    class_attribute :bases, :conditionals, :events

    # Set Defaults
    self.pigeon_config_file = nil
    self.cooldown = 2.days

    # Initialize
    self.bases = []
    self.conditionals = []
    self.events = []
  end

  # returns will be { flight_name: [ { letter: letter_a, query: sql query, count: result count, entity: type of entity }, { ... } ] } ...
  def self.assemble(options={})
    opts = {
      debug: false,
      deep_debug: false, # include flight results in debug output
      send: true
    }.with_indifferent_access.merge(options)

    '''Assembles all base entities deserving a post in this flight'''

    # First, we're going to check that PigeonMailer and PigeonLetter exist (and are as we'd expect)
    require 'pigeon_letter' unless defined?(PigeonLetter)
    require 'pigeon_mailer' unless defined?(PigeonMailer)

    # We'll set a natural default location if Rails is defined
    Settings.pigeon_config_file ||= "#{Rails.root}/config/pigeons.json" if defined?(Rails)

    raise PigeonError::PigeonConfigError, "Must create PigeonMailer mailer (TODO: instructions)" unless defined?(PigeonMailer) && ( PigeonMailer < ActionMailer::Base )
    raise PigeonError::PigeonConfigError, "Must create PigeonLetter model (TODO: instructions)" unless defined?(PigeonLetter) && ( PigeonLetter < ActiveRecord::Base )

    # Next, we're going to pull the configuration JSON file
    raise PigeonError::PigeonConfigError, "Must set pigeon_config_file" if Settings.pigeon_config_file.blank?
    raise PigeonError::PigeonConfigError, "Missing pigeon configuration file: #{Settings.pigeon_config_file}" if !File.exists?(Settings.pigeon_config_file)
    
    pigeon_config = begin
      JSON(File.read(Settings.pigeon_config_file)) # TODO: Caching?
    rescue JSON::ParserError => e
      raise PigeonError::PigeonConfigError, "Error parsing pigeon configuration file: #{e.inspect}"
    end

    # Flights are the "cohorts" defined what and how to send letters to our entities (e.g. users)
    flights = Hash[pigeon_config['flights'].sort]
    raise PigeonError::PigeonConfigError, "Configuration must include flights object" if flights.nil?

    results = {}

    # Note, order here is important (for mod i), and thus, we've sorted flights alphabeticaly to maintain consistency
    flights.each_with_index do |(flight, flight_info), flight_id|
      Pigeons::Logger.log [ 'Pigeons::', 'Flight::', flight ] if opts[:debug]

      results[flight] = []

      # We'll allow flight: [ ... ] instead of flight: { letters: [ ... ] } for shorthand if other options are not needed
      flight_info = { 'letters' => flight_info } if flight_info.is_a?(Array)
      
      base_scope = default_base_scope = if flight_info['base'] # Note, this will usually be nil, but it can be set specifically
        Scope.get_base_scope(flight_info['base'])
      end
      
      raise PigeonError::PigeonFlightConfigError, "Letters must be present in flight" if flight_info['letters'].empty?

      previous_letters = []

      flight_info['letters'].each_with_index do |letter_info, i|

        Pigeons::Logger.debug [ 'Pigeons::', "Flight #{flight}", "Letter Info", letter_info ] if opts[:debug]
        # This is going to parse the letter info and make sure it makes sense
        elements = Elements.parse_elements(letter_info)

        # Let's see if we were able to parse letter info
        raise PigeonError::PigeonFlightConfigError, "Failed to parse letter info for flight #{flight}: \"#{letter_info}\".  Should be like \"someone\" gets a \"type a\" letter \"sometime\" after \"some event\"" if elements.nil?

        # Otherwise, convert capture groups to a nice hash
        elements = Hash[elements.names.zip(elements.captures)].with_indifferent_access

        # args such as default base scope? maybe we should change to an arguments hash
        # note: for running conditionals, we could verify they skip the previous scopes, but this is going to
        # end up a complicated query.  we're going to rely on letter-existence skipping instead
        scope_res = Scope.get_scope(elements: elements, previous_base_scope: base_scope, previous_letters: previous_letters, flights: flights, flight: flight, flight_id: flight_id, letter_info: letter_info, opts: opts)
        
        scope = scope_res[:scope]
        base_scope = scope_res[:base_scope]
        previous_letters = scope_res[:previous_letters]
        letter = scope_res[:letter]
        entity = scope_res[:entity]

        Pigeons::Logger.debug [ 'Pigeons::', "Flight #{flight} Letter", letter_info ] if opts[:debug]
        Pigeons::Logger.debug [ 'Pigeons::', "Flight #{flight} Scope", scope.explain ] if opts[:debug]
        Pigeons::Logger.debug [ 'Pigeons::', "Flight #{flight} Count", scope.count ] if opts[:debug]
        Pigeons::Logger.debug [ 'Pigeons::', "Flight #{flight} Results", scope ] if opts[:deep_debug]

        results[flight].push(letter: letter, query: scope.to_sql, count: scope.count, entity: entity, scope: scope)

        # TODO: We could break this out?
        self.send_letter(scope, letter, flight) if opts[:send]
      end
    end

    results
  end

  # Add base will add a match clause to our checks in parsing
  # scope_block is a proc that will return a scope used in further flight tests
  def self.add_base(matcher, clause)
    Settings.bases.push(matcher: matcher, clause: clause)
  end

  # Add a conditional block
  # If a condition matches this conditional block, it will append its where clause
  def self.add_conditional(matcher, clause)
    Settings.conditionals.push(matcher: matcher, clause: clause)
  end

  def self.add_event(matcher, clause)
    Settings.events.push(matcher: matcher, clause: clause)
  end

  public # TODO: should these change to private?

    # This is responsible for the actual send letter aspect
    # It will create PigeonLetters and call delivery
    # to PigeonMailer
    def self.send_letter(scope, letter_type, flight)
      # The question we face here is, do we create letters one-by-one, or do we create the letters in bulk
      # possibly updating sent_at after sending

      # Also, how do we send letters?
      # Is that asynchronous?

      # Let's just do this quick and dirty and come back to this
      scope.find_each do |cargo|
        letter = PigeonLetter.create!(cargo: cargo, letter_type: letter_type, flight: flight)
        
        # Send the letter -- note, we may want to also send info about flights for tracking
        begin
          letter.send!
        rescue => e # We're going to rescue here to save ourselves the humiliation of failing.
          # It would be nice to log this at the PigeonLetter (database) or return level
          p [ 'Pigeons::SendLetter', 'Failed to send letter', e ]
        end
      end
    end
    
end