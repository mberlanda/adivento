class WalletGrantService
  def self.approve!(faucet_request:, actor:, note: nil)
    ApplicationRecord.transaction do
      faucet_request.update!(status: :approved, reviewed_by: actor, note: note)

      wallet = faucet_request.user.wallet
      wallet.update!(available_minor: wallet.available_minor + faucet_request.amount_minor)

      LedgerEntry.create!(
        user: faucet_request.user,
        actor: actor,
        entry_type: "FAUCET_GRANT",
        amount_minor: faucet_request.amount_minor,
        direction: "credit",
        metadata: { faucet_request_id: faucet_request.id }
      )

      AuditEvent.create!(
        actor: actor,
        action: "faucet_request.approve",
        target_type: "FaucetRequest",
        target_id: faucet_request.id,
        reason: note,
        metadata: { amount_minor: faucet_request.amount_minor }
      )
    end
  end

  def self.reject!(faucet_request:, actor:, note: nil)
    faucet_request.update!(status: :rejected, reviewed_by: actor, note: note)

    AuditEvent.create!(
      actor: actor,
      action: "faucet_request.reject",
      target_type: "FaucetRequest",
      target_id: faucet_request.id,
      reason: note,
      metadata: {}
    )
  end
end
