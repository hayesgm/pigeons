ENV["RAILS_ENV"] = "test"
require File.expand_path('../../../../config/environment', __FILE__)

require 'test/unit'
require 'pigeons'
require 'mocha'
include Mocha

::NOW = ::Time.now
::CURRENT = ::Time.current

::Time.stubs(now: ::NOW) # Make this static for a test
::Time.stubs(current: ::CURRENT)

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => ':memory:'
)

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :dragons, :force => true do |t|
    t.string :property
    t.string :color
    t.boolean :eaten
    t.boolean :slept
    t.datetime :hatched_at
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table :orcs, :force => true do |t|
    t.string :name
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table :battles, :force => true do |t|
    t.integer :dragon_id
    t.integer :orc_id
    t.boolean :is_dragon_victor
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table :pixies, :force => true do |t|
    t.string :text
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

  create_table :levels, :force => true do |t|
    t.integer :pixie_id
    t.integer :level
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end
  
  create_table :pigeon_letters, :force => true do |t|
    t.string   "letter_type"
    t.string   "cargo_type"
    t.integer  "cargo_id"
    t.datetime "sent_at"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
  end

end

# Clear these out in case they were used by any project settings
Pigeons::Settings.bases = []
Pigeons::Settings.conditionals = []
Pigeons::Settings.events = []

# Let's check classify works nicely
ActiveSupport::Inflector.inflections do |inflect|
  inflect.irregular 'pixie', 'pixies'
end

# This is the scope that's going to be on every object by the very nature of pigeons
# Thus, we'll make helpers for them
def letter_not_exists(scope, letter_type)
  pigeon_arel = PigeonLetter.arel_table
  source_arel = scope.arel_table

  scope.where(
    PigeonLetter.where(
      pigeon_arel[:cargo_id].eq(source_arel[:id]).and(
        pigeon_arel[:cargo_type].eq(source_arel.name.classify)
      ).and(
        pigeon_arel[:created_at].not_eq(nil)
      ).and(
        pigeon_arel[:letter_type].eq(letter_type.to_s)
      )
    ).exists.not
  )
end

def simple_scope(scope, count=1, id=0)
  pigeon_arel = PigeonLetter.arel_table
  source_arel = scope.arel_table

  scope.where("id%#{count}=#{id}").where(
    PigeonLetter.where(
      pigeon_arel[:cargo_id].eq(source_arel[:id]).and(
        pigeon_arel[:cargo_type].eq(source_arel.name.classify)
      ).and(
        pigeon_arel[:created_at].gt(Pigeons::Settings.cooldown.ago)
      )
    ).exists.not
  )
end

class Dragon < ActiveRecord::Base
  has_many :battles
end

class Orc < ActiveRecord::Base
  has_many :battles
end

class Battle < ActiveRecord::Base
  belongs_to :dragon
  belongs_to :orc
end

class Pixie < ActiveRecord::Base
  has_many :levels
end

class Level < ActiveRecord::Base
  belongs_to :pixie
end

class PigeonLetter < ActiveRecord::Base

end
