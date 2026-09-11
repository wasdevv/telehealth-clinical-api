# Append-only record of who touched PHI, what, when and from where. There is no
# updated_at and no destroy path: an audit row that can be rewritten audits nothing.
class AuditLog < ApplicationRecord
  belongs_to :user
  belongs_to :resource, polymorphic: true

  validates :action, presence: true

  def self.record!(user:, resource:, action:, ip: nil)
    create!(user: user, resource: resource, action: action, ip_address: ip)
  end

  def readonly?
    persisted?
  end
end
