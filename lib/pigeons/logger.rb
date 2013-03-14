module Pigeons
  class Logger
    
    def self.log(*args)
      Rails.logger.info(*args) if defined?(Rails)
      p *args
    end

    def self.debug(*args)
      Rails.logger.debug(*args) if defined?(Rails)
      p *args
    end

  end
end