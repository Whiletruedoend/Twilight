# frozen_string_literal: true

class ApplicationSearch
  extend Dry::Initializer[undefined: false]

  def self.call(...)
    new(...).call
  end
end
