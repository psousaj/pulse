class User < ApplicationRecord
  belongs_to :account

  has_many :api_access_tokens, dependent: :delete_all
  has_many :api_refresh_tokens, dependent: :delete_all

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
