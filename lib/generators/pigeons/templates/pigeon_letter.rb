# Represents a letter sent by Pigeons
# 
# Attributes
# letter_type:: Type of letter being sent
# cargo_id:: Associated object id (e.g. a <user_id>) *polymorphic
# cargo_type:: Assoication type (e.g. User) *polymorphic
# sent_at:: Time letter was sent
# flight:: What flight was this sent on?
class PigeonLetter < ActiveRecord::Base

  ### Associations
  belongs_to :cargo, polymorphic: true

  ### Attributes
  attr_accessible :letter_type, :cargo, :cargo_id, :cargo_type, :flight

  ### Validations
  validates_presence_of :letter_type
  validates_presence_of :cargo_id
  validates_presence_of :cargo_type
  validates_presence_of :flight

  ### Member Functions

  def send!
    PigeonMailer.send(letter_type, cargo, flight).deliver
    self.update_attribute(:sent_at, Time.now)
  end

end
