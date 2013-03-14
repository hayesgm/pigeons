require 'rails/generators'
require 'rails/generators/active_record'

module Pigeons

  class InstallGenerator < Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path('../templates', __FILE__)
    
    # desc "Some description of my generator here"

    # Commandline options can be defined here using Thor-like options:
    # class_option :my_opt, :type => :boolean, :default => false, :desc => "My Option"

    # I can later access that option using:
    # options[:my_opt]

    # Generator Code. Remember this is just suped-up Thor so methods are executed in order
    def generate_pigeons_json
      copy_file "pigeons.json", "config/pigeons.json"
    end

    def generate_pigeon_letter
      copy_file "pigeon_letter.rb", "app/models/pigeon_letter.rb"
    end

    def generate_pigeon_letter_migration
      migration_template "pigeon_letter_migration.rb", "db/migrate/create_pigeon_letters"
    end

    def generate_pigeon_mailer
      copy_file "pigeon_mailer.rb", "app/mailers/pigeon_mailer.rb"
    end

    def self.next_migration_number(dirname)
      ActiveRecord::Generators::Base.next_migration_number(dirname)
    end

  end

end