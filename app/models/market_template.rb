class MarketTemplate < ApplicationRecord
	serialize :default_legs, coder: JSON

	validates :key, presence: true, uniqueness: true
	validates :name, presence: true
	validates :default_duration_hours, numericality: { greater_than: 0 }

	def legs
		Array(default_legs).presence || ["YES", "NO"]
	end
end
