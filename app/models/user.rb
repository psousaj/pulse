class User < ApplicationRecord
  belongs_to :account

  enum :role, {
    owner: "owner",
    admin: "admin",
    editor: "editor",
    viewer: "viewer"
  }, default: :owner, validate: true

  validates :email, presence: true
  validates :name, presence: true
  validates :email, uniqueness: { scope: :account_id }
end
