require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  minimum_coverage 90
  track_files "app/{controllers,models,services}/**/*.rb"
  add_filter "/test/"
  add_filter "/app/channels/"
  add_filter "/app/jobs/"
  add_filter "/app/mailers/"
end

ENV['RAILS_ENV'] ||= 'test'
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end

class ActionDispatch::IntegrationTest
  def auth_headers_for(user)
    {
      "Authorization" => "Bearer #{JsonWebToken.encode({ user_id: user.id })}",
      "Content-Type" => "application/json"
    }
  end
end
