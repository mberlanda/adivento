class UserGrant < ApplicationRecord
  belongs_to :user
  belongs_to :permission
  belongs_to :granted_by, class_name: "User"

  scope :active_now, -> {
    where("expires_at IS NULL OR expires_at > ?", Time.current)
  }

  validates :reason, presence: true
  validates :allow, inclusion: { in: [true, false] }
end
