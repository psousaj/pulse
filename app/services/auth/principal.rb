module Auth
  class Principal
    attr_reader :subject, :username, :email, :permissions, :account_slug, :claims,
      :access_token, :refresh_token, :id_token, :expires_at

    def self.from_payload(payload, access_token: nil, refresh_token: nil, id_token: nil, expires_at: nil)
      permissions = extract_permissions(payload)

      new(
        subject: payload["sub"].to_s,
        username: payload["preferred_username"].presence || payload["name"].presence || payload["email"].to_s,
        email: payload["email"].to_s,
        permissions: permissions,
        account_slug: payload[Settings.account_claim].to_s,
        claims: payload,
        access_token: access_token,
        refresh_token: refresh_token,
        id_token: id_token,
        expires_at: expires_at
      )
    end

    def self.from_session_hash(payload, access_token: nil, refresh_token: nil, id_token: nil, expires_at: nil)
      from_payload(payload.to_h, access_token:, refresh_token:, id_token:, expires_at:)
    end

    def self.extract_permissions(payload)
      value = payload[Settings.permissions_claim]

      case value
      when Array
        value.filter_map(&:presence).map(&:to_s).uniq
      when String
        value.split(/[\s,]+/).reject(&:blank?).uniq
      else
        []
      end
    end

    def initialize(subject:, username:, email:, permissions:, account_slug:, claims:, access_token:, refresh_token:, id_token:, expires_at:)
      @subject = subject
      @username = username
      @email = email
      @permissions = permissions
      @account_slug = account_slug
      @claims = claims
      @access_token = access_token
      @refresh_token = refresh_token
      @id_token = id_token
      @expires_at = expires_at
    end

    def name
      username.presence || email.presence || subject
    end

    def id
      subject
    end

    def present?
      subject.present?
    end

    def blank?
      !present?
    end

    def admin?
      permissions.include?("admin")
    end

    def has_permission?(permission)
      admin? || permissions.include?(permission.to_s)
    end

    def session_hash
      claims.slice("sub", "preferred_username", "name", "email", Settings.account_claim, Settings.permissions_claim)
    end
  end
end
