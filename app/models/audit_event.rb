class AuditEvent < ApplicationRecord
  belongs_to :actor, class_name: 'User'

  validates :action, :target_type, :target_id, presence: true
end
