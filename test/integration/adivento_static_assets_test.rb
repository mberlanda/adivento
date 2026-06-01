require 'test_helper'

class AdiventoStaticAssetsTest < ActionDispatch::IntegrationTest
  test 'layouts include content-hash query strings for static design assets' do
    css_version = Digest::SHA256.file(Rails.public_path.join('adivento.css')).hexdigest.first(12)
    js_version = Digest::SHA256.file(Rails.public_path.join('adivento.js')).hexdigest.first(12)

    get '/'

    assert_response :success
    assert_select %(link[rel="stylesheet"][href="/adivento.css?v=#{css_version}"])
    assert_select %(script[src="/adivento.js?v=#{js_version}"])

    post '/signin', params: { email: users(:admin).email, password: 'password123' }
    get '/backoffice'

    assert_response :success
    assert_select %(link[rel="stylesheet"][href="/adivento.css?v=#{css_version}"])
    assert_select %(script[src="/adivento.js?v=#{js_version}"])
  end
end
