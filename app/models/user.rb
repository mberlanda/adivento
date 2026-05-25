class User < ApplicationRecord
	has_secure_password

	enum :role, { admin: 0, moderator: 1, player: 2 }, default: :player

	has_one :wallet, dependent: :destroy
	has_many :created_markets, class_name: "Market", foreign_key: :created_by_id, dependent: :nullify, inverse_of: :created_by
	has_many :settled_markets, class_name: "Market", foreign_key: :settled_by_id, dependent: :nullify, inverse_of: :settled_by
	has_many :faucet_requests, dependent: :destroy
	has_many :ledger_entries, dependent: :restrict_with_exception

	validates :email, presence: true, uniqueness: true
	validates :role, presence: true

	before_validation :normalize_email
	after_create :ensure_wallet

	private

	def normalize_email
		self.email = email.to_s.strip.downcase
	end

	def ensure_wallet
		create_wallet! unless wallet
	end
end
