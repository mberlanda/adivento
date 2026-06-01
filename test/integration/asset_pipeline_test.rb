require 'test_helper'

class AssetPipelineTest < ActionDispatch::IntegrationTest
  # Propshaft fingerprints the design-system files so a content change yields a
  # new URL (cache-busting), instead of the old fixed /adivento.css path.
  test 'customer layout references content-digested design-system assets' do
    get '/'

    assert_response :success
    assert_select 'link[rel="stylesheet"][href^="/assets/adivento-"][href$=".css"]'
    assert_select 'script[src^="/assets/adivento-"][src$=".js"]'
    assert_select 'meta[name="theme-color"][content="#FAF7F2"]'
    assert_select 'link[rel="icon"][type="image/svg+xml"][href^="/assets/adivento/favicon-"][href$=".svg"]'
    assert_select 'link[rel="apple-touch-icon"][href^="/assets/adivento/app-icon-"][href$=".svg"]'
    assert_select 'img.ds-brand-logo[alt="Adivento"][src^="/assets/adivento/logo-horizontal-"][src$=".svg"]'
  end

  test 'backoffice layout references content-digested design-system assets' do
    post '/signin', params: { email: users(:admin).email, password: 'password123' }
    get '/backoffice'

    assert_response :success
    assert_select 'link[rel="stylesheet"][href^="/assets/adivento-"][href$=".css"]'
    assert_select 'script[src^="/assets/adivento-"][src$=".js"]'
    assert_select 'meta[name="theme-color"][content="#0F5136"]'
    assert_select 'link[rel="icon"][type="image/svg+xml"][href^="/assets/adivento/favicon-"][href$=".svg"]'
    assert_select 'link[rel="apple-touch-icon"][href^="/assets/adivento/app-icon-"][href$=".svg"]'
    assert_select 'img.ds-brand-logo[alt="Adivento"][src^="/assets/adivento/logo-horizontal-"][src$=".svg"]'
  end

  test 'design-system stylesheet exposes market signal brand tokens' do
    css = Rails.root.join('app/assets/stylesheets/adivento.css').read

    assert_includes css, '--ds-deep-green:    #0F5136;'
    assert_includes css, '--ds-teal:          #1E7C6B;'
    assert_includes css, '--ds-seafoam:       #7FAE9D;'
    assert_includes css, '--ds-sand:          #E9DFCF;'
    assert_includes css, '--ds-off-white:     #FAF7F2;'
    assert_includes css, '--ds-ink:           #1F2A26;'
    assert_includes css, '--ds-stone:         #8C8376;'
    assert_includes css, 'font-family: "Inter", "Aptos", "Segoe UI", system-ui, -apple-system, sans-serif;'
  end
end
