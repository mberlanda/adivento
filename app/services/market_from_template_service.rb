class MarketFromTemplateService
  def self.create!(template:, question:, description:, creator:)
    ApplicationRecord.transaction do
      market = Market.create!(
        question: question,
        description: description,
        status: :draft,
        created_by: creator
      )

      template.legs.each do |label|
        market.market_legs.create!(label: label, odds_minor: 5000, active: true)
      end

      AuditEvent.create!(
        actor: creator,
        action: 'market.template_used',
        target_type: 'Market',
        target_id: market.id,
        metadata: { template_key: template.key }
      )

      market
    end
  end
end
