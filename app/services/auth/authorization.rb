module Auth
  module Authorization
    module_function

    def require_any_permission!(permissions, principal: Current.user)
      normalized_permissions = Array(permissions).flatten.map(&:to_s).reject(&:blank?)
      return if allowed_any?(normalized_permissions, principal:)

      raise ForbiddenError, "insufficient_permissions"
    end

    def allowed_any?(permissions, principal: Current.user)
      return false if principal.blank?
      return true if principal.admin?

      permissions.any? { |permission| principal.has_permission?(permission) }
    end
  end
end
