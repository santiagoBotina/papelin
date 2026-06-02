# frozen_string_literal: true

# Additional SimpleCov configuration (loaded after SimpleCov.start in spec_helper.rb).
# Groups, filters, and coverage thresholds.

SimpleCov.minimum_coverage 80
SimpleCov.refuse_coverage_drop

SimpleCov.start do
  add_filter '/app/javascript/'
  add_filter '/app/views/'
  add_filter '/app/assets/'
  add_filter '/app/channels/'
  add_filter '/app/mailers/'

  add_group 'Services', 'app/services'
  add_group 'Policies', 'app/policies'
  add_group 'Jobs', 'app/jobs'
  add_group 'Helpers', 'app/helpers'
end
