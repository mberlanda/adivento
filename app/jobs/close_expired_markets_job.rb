class CloseExpiredMarketsJob < ApplicationJob
  queue_as :default

  def perform
    expired = Market.open.where.not(close_at: nil).where(close_at: ..Time.current)

    expired.find_each do |market|
      updated = Market.where(id: market.id, status: Market.statuses[:open])
                      .update_all(status: Market.statuses[:closed])
      next unless updated.positive?

      AuditEvent.create!(
        action: 'market.close',
        actor: system_actor,
        target_type: 'Market',
        target_id: market.id,
        metadata: { close_at: market.close_at.iso8601, triggered_by: 'CloseExpiredMarketsJob' }
      )
    rescue StandardError => e
      Rails.logger.error("[CloseExpiredMarketsJob] Failed to close market #{market.id}: #{e.message}")
    end
  end

  private

  def system_actor
    @system_actor ||= User.where(role: User.roles[:admin]).first || User.first
  end
end
