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

    assert_match(/--ds-deep-green:\s*#0F5136;/, css)
    assert_match(/--ds-teal:\s*#1E7C6B;/, css)
    assert_match(/--ds-seafoam:\s*#7FAE9D;/, css)
    assert_match(/--ds-sand:\s*#E9DFCF;/, css)
    assert_match(/--ds-off-white:\s*#FAF7F2;/, css)
    assert_match(/--ds-ink:\s*#1F2A26;/, css)
    assert_match(/--ds-stone:\s*#8C8376;/, css)
    assert_includes css, 'font-family: "Inter", "Aptos", "Segoe UI", system-ui, -apple-system, sans-serif;'
  end

  test 'design-system javascript synchronizes browser theme color' do
    js = Rails.root.join('app/assets/javascripts/adivento.js').read

    assert_match(/THEME_COLORS\s*=\s*\{[^}]*light:\s*"#FAF7F2"[^}]*dark:\s*"#0F5136"/m, js)
    assert_includes js, 'meta[name="theme-color"]'
    assert_includes js, 'syncThemeColor(name)'
  end

  test 'root favicon ico is served for browser fallback requests' do
    get '/favicon.ico'

    assert_response :success
    assert_equal 'image/vnd.microsoft.icon', response.media_type
    assert_operator response.body.bytesize, :>, 0
  end

  test 'active storage image variants are disabled for static brand assets' do
    assert_equal :disabled, Rails.application.config.active_storage.variant_processor
  end
end
