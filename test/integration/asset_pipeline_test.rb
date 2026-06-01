require 'test_helper'

class AssetPipelineTest < ActionDispatch::IntegrationTest
  # Propshaft fingerprints the design-system files so a content change yields a
  # new URL (cache-busting), instead of the old fixed /adivento.css path.
  test 'customer layout references content-digested design-system assets' do
    get '/'

    assert_response :success
    assert_select 'link[rel="stylesheet"][href^="/assets/adivento-"][href$=".css"]'
    assert_select 'script[src^="/assets/adivento-"][src$=".js"]'
  end

  test 'backoffice layout references content-digested design-system assets' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }
    get '/backoffice'

    assert_response :success
    assert_select 'link[rel="stylesheet"][href^="/assets/adivento-"][href$=".css"]'
    assert_select 'script[src^="/assets/adivento-"][src$=".js"]'
  end
end
