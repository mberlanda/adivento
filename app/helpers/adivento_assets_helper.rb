require 'digest'

module AdiventoAssetsHelper
  def adivento_asset_path(filename)
    filename = filename.to_s.delete_prefix('/')
    version = AdiventoAssetsHelper.asset_version(filename)
    path = "/#{filename}"
    version.present? ? "#{path}?v=#{version}" : path
  end

  def self.asset_version(filename)
    @asset_versions ||= {}
    @asset_versions[filename] ||= begin
      path = Rails.public_path.join(filename)
      Digest::SHA256.file(path).hexdigest.first(12) if File.file?(path)
    end
  end
end
