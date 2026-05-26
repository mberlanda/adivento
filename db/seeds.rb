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
	user = User.find_or_initialize_by(email: attrs[:email])
	user.password = "password123" if user.new_record?
	user.role = attrs[:role]
	user.active = true
	user.save!
end

Seeds::SyncPermissionsService.call!
Seeds::SyncRolePermissionsService.call!
Seeds::SyncMarketTemplatesService.call!
