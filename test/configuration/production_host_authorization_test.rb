require 'minitest/autorun'
require 'open3'

class ProductionHostAuthorizationTest < Minitest::Test
  APP_ROOT = File.expand_path('../..', __dir__)

  def test_production_allows_the_render_cromoswap_hostname
    host = 'cromoswap.onrender.com'
    command = "host = #{host.inspect}; abort(\"missing #{host}\") unless Rails.application.config.hosts.include?(host)"

    _stdout, stderr, status = Open3.capture3(
      { 'RAILS_ENV' => 'production', 'SECRET_KEY_BASE_DUMMY' => '1' },
      File.join(APP_ROOT, 'bin/rails'),
      'runner',
      command,
      chdir: APP_ROOT
    )

    assert_predicate status, :success?, stderr
  end
end
