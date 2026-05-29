class WalletGrantService
  class InvalidGrant < StandardError; end

  def self.approve!(faucet_request:, actor:, note: nil)
    ApplicationRecord.transaction do
      # Lock the request row and re-check its state inside the transaction so the
      # same request cannot be approved twice (double-credit) under concurrency.
      request = FaucetRequest.lock.find(faucet_request.id)
      raise InvalidGrant, 'Faucet request is not pending' unless request.pending?

      request.update!(status: :approved, reviewed_by: actor, note: note)

      wallet = request.user.wallet.lock!
      wallet.update!(available_minor: wallet.available_minor + request.amount_minor)

      LedgerEntry.create!(
        user: request.user,
        actor: actor,
        entry_type: 'FAUCET_GRANT',
        amount_minor: request.amount_minor,
        direction: 'credit',
        metadata: { faucet_request_id: request.id }
      )

      AuditEvent.create!(
        actor: actor,
        action: 'faucet_request.approve',
        target_type: 'FaucetRequest',
        target_id: request.id,
        reason: note,
        metadata: { amount_minor: request.amount_minor }
      )
    end
  end

  def self.reject!(faucet_request:, actor:, note: nil)
    faucet_request.update!(status: :rejected, reviewed_by: actor, note: note)

    AuditEvent.create!(
      actor: actor,
      action: 'faucet_request.reject',
      target_type: 'FaucetRequest',
      target_id: faucet_request.id,
      reason: note,
      metadata: {}
    )
  end
end
