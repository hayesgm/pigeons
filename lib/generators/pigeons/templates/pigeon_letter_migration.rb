class CreatePigeonLetters < ActiveRecord::Migration
  def change
    create_table :pigeon_letters do |t|
      t.string :letter_type
      t.string :flight
      t.string :cargo_type
      t.integer :cargo_id
      t.datetime :sent_at

      t.timestamps
    end

    add_index :pigeon_letters, [ :cargo_id, :cargo_type ], :name => "index_pigeon_letters_cargo_id_cargo_type"
    add_index :pigeon_letters, [ :letter_type ], :name => "index_pigeon_letters_letter_type"
  end
end
