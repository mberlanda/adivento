module Seeds
  class SyncMarketTemplatesService
    def self.call!
      desired_keys = Catalogs::MarketTemplateCatalog.keys

      MarketTemplate.transaction do
        Catalogs::MarketTemplateCatalog::TEMPLATES.each do |row|
          template = MarketTemplate.find_or_initialize_by(key: row.fetch(:key))
          template.assign_attributes(row)
          template.save! if template.changed?
        end

        MarketTemplate.where.not(key: desired_keys).update_all(active: false, updated_at: Time.current)
      end
    end
  end
end
