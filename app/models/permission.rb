class Permission < ApplicationRecord
  has_many :role_permissions, dependent: :destroy
  has_many :user_grants, dependent: :destroy

  validates :key, presence: true, uniqueness: true
  validates :active, inclusion: { in: [true, false] }
end
