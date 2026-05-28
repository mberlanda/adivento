module Catalogs
  class PermissionCatalog
    PERMISSIONS = [
      { key: 'backoffice.access', description: 'Access backoffice web and admin operations', active: true,
        default_roles: %w[admin moderator] },
      { key: 'permission.manage', description: 'Manage role permission mappings', active: true,
        default_roles: %w[admin] },
      { key: 'grant.manage', description: 'Create user-level allow/deny grants', active: true,
        default_roles: %w[admin] },
      { key: 'bet.place', description: 'Place bets on open markets', active: true, default_roles: %w[admin player] },
      { key: 'bet.void', description: 'Void active bets with reason', active: true,
        default_roles: %w[admin moderator] },
      { key: 'risk.read', description: 'Read market risk and liability metrics', active: true,
        default_roles: %w[admin moderator] },
      { key: 'market.read', description: 'Read market management data', active: true,
        default_roles: %w[admin moderator] },
      { key: 'market.create', description: 'Create markets', active: true, default_roles: %w[admin] },
      { key: 'market.update', description: 'Update market metadata', active: true, default_roles: %w[admin] },
      { key: 'market.leg.create', description: 'Create additional legs for a market', active: true,
        default_roles: %w[admin moderator] },
      { key: 'market.settle', description: 'Settle markets', active: true, default_roles: %w[admin moderator] },
      { key: 'wallet.faucet.review', description: 'Approve or reject faucet requests', active: true,
        default_roles: %w[admin moderator] },
      { key: 'template.manage', description: 'Manage market templates', active: true,
        default_roles: %w[admin moderator] }
    ].freeze

    def self.keys
      PERMISSIONS.pluck(:key)
    end
  end
end
