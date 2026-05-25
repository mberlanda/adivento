# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
[
	{ email: "admin@adivento.local", role: :admin },
	{ email: "moderator@adivento.local", role: :moderator },
	{ email: "player@adivento.local", role: :player }
].each do |attrs|
	User.find_or_create_by!(email: attrs[:email]) do |user|
		user.password = "password123"
		user.role = attrs[:role]
		user.active = true
	end
end

permissions = [
	["backoffice.access", "Access backoffice web and admin operations"],
	["permission.manage", "Manage role permission mappings"],
	["grant.manage", "Create user-level allow/deny grants"],
	["market.read", "Read market management data"],
	["market.create", "Create markets"],
	["market.update", "Update market metadata"],
	["market.leg.create", "Create additional legs for a market"],
	["market.settle", "Settle markets"],
	["wallet.faucet.review", "Approve or reject faucet requests"],
	["template.manage", "Manage market templates"]
]

permissions.each do |key, description|
	Permission.find_or_create_by!(key: key) do |permission|
		permission.description = description
		permission.active = true
	end
end

role_map = {
	"admin" => permissions.map(&:first),
	"moderator" => [
		"backoffice.access",
		"market.read",
		"market.leg.create",
		"market.settle",
		"wallet.faucet.review",
		"template.manage"
	],
	"player" => []
}

RolePermission.delete_all
role_map.each do |role_name, permission_keys|
	permission_keys.each do |key|
		RolePermission.create!(role_name: role_name, permission: Permission.find_by!(key: key))
	end
end

[
	{
		key: "binary_yes_no",
		name: "Binary Yes/No",
		description: "Simple yes or no market template",
		default_legs: ["YES", "NO"],
		default_duration_hours: 24,
		active: true
	},
	{
		key: "sports_winner",
		name: "Sports Winner",
		description: "Head to head outcome template",
		default_legs: ["TEAM_A", "TEAM_B"],
		default_duration_hours: 12,
		active: true
	},
	{
		key: "macro_direction",
		name: "Macro Direction",
		description: "Up/down directional event template",
		default_legs: ["UP", "DOWN"],
		default_duration_hours: 48,
		active: true
	}
].each do |attrs|
	template = MarketTemplate.find_or_initialize_by(key: attrs[:key])
	template.assign_attributes(attrs)
	template.save!
end
