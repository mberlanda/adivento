module Catalogs
  class ActionCatalog
    ACTIONS = [
      { key: 'navigation.markets', surface: 'navigation', path: '/web/markets', method: 'get', permission_key: nil,
        audience: 'all' },
      { key: 'navigation.backoffice', surface: 'navigation', path: '/backoffice', method: 'get',
        permission_key: 'backoffice.access', audience: 'signed_in' },
      { key: 'navigation.sign_in', surface: 'navigation', path: '/signin', method: 'get', permission_key: nil,
        audience: 'guest' },
      { key: 'navigation.sign_out', surface: 'navigation', path: '/signout', method: 'delete', permission_key: nil,
        audience: 'signed_in' },
      { key: 'navigation.profile', surface: 'navigation', path: '/web/profile', method: 'get', permission_key: nil,
        audience: 'signed_in' },
      { key: 'capability.bet.place', surface: 'capability', path: '/markets/:market_id/bets', method: 'post',
        permission_key: 'bet.place', audience: 'signed_in' },
      { key: 'capability.risk.read', surface: 'capability', path: '/admin/markets/:id/risk', method: 'get',
        permission_key: 'risk.read', audience: 'signed_in' }
    ].freeze
  end
end
