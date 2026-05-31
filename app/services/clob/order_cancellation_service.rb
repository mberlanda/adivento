module Clob
  class OrderCancellationService
    Result = Struct.new(:success?, :order, :released_minor, :errors, keyword_init: true)

    def self.call(order:, actor:)
      new(order: order, actor: actor).call
    end

    def initialize(order:, actor:)
      @order = order
      @actor = actor
    end

    def call
      released = nil
      locked = nil

      ApplicationRecord.transaction do
        locked = Order.lock.find(@order.id)
        raise ActiveRecord::Rollback unless cancellable?(locked)

        released = locked.reserved_minor
        locked.cancelled_quantity += locked.unfilled_quantity
        locked.status = :cancelled
        locked.save!

        wallet = locked.user.wallet.lock!
        wallet.update!(
          reserved_minor: wallet.reserved_minor - released,
          available_minor: wallet.available_minor + released
        )

        AuditEvent.create!(
          action: 'order.cancel',
          actor: @actor,
          target_type: 'Order',
          target_id: locked.id,
          metadata: { released_minor: released, market_id: locked.market_id }
        )
      end

      if released.nil?
        Result.new(success?: false, order: @order, released_minor: 0, errors: ['Order cannot be cancelled'])
      else
        Result.new(success?: true, order: locked, released_minor: released, errors: [])
      end
    rescue StandardError => e
      Result.new(success?: false, order: @order, released_minor: 0, errors: [e.message])
    end

    private

    def cancellable?(order)
      order.open? || order.partial?
    end
  end
end
