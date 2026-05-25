class RolePermission < ApplicationRecord
  belongs_to :permission

  validates :role_name, presence: true
  validates :permission_id, uniqueness: { scope: :role_name }
end
