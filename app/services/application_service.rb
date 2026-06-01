# frozen_string_literal: true

# Base class for all service objects in the application.
# Provides shared conventions:
#   - `.call` class method that delegates to an instance
class ApplicationService
  # Every service returns a Result struct with keyword_init: true.
  # Subclasses may define their own Result with additional fields.
  Result = Struct.new(:success?, :data, :error, keyword_init: true)

  def self.call(...)
    new(...).call
  end
end
