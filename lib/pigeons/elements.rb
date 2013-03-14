
module Pigeons

  module Elements

    # This is the beast of our regex base parsing library
    # He is going to parse all discernable elements from the string
    # And send it back as elements
    def self.parse_elements(letter)
      article = /a(?:[n]?|ll)/ix
      base_element = /(#{article}\s+)? (?<base_element>[\w\s]+?)/ix
      conditionals = /(who((\'ve)|(\s+ have))?\s+) (?<conditionals>[\w\s]+)/ix
      letter_type = /(#{article}\s+)? (?<letter>[\w\s]+) \s+ letter/ix
      time_metric = /( (?<time_metric_coefficient>\d+) \s+)? (?<time_metric_unit>time|second|minute|hour|day|week|fortnight|month|year)(s?)/ix
      time_qualifier = /(?<relative>after) \s+ (?<time_item>[^.!$]+)/ix
      time_clause = /((?<recurring>every)\s+)? (?<time_metric>#{time_metric})? (\s*#{time_qualifier})?/ix
      
      grammar = /^\s*                 # Allow whitespace
        ((?<joiner>and|then)\s+)?     # Joiner is and or then
        (#{base_element} \s+)?        # Base element as ActiveRecord type or base block
        (#{conditionals} \s+)?        # Who ... condition block
        get(s)? \s+                   # get
        #{letter_type}                # a ... letter
        (\s+ #{time_clause})?         # after letter or event block
        \s*[.!]?                      # optional punctuation
        \s*                           # allow whitespace
      $/ix

      # Pigeons::Logger.debug [ 'Grammar', grammar ]
      grammar.match(letter)
    end

  end

end