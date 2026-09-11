module Types
  class UserRoleEnum < BaseEnum
    description "What an account is allowed to see"

    User::ROLES.each { |role| value role.upcase, value: role }
  end
end
