import Config

config :ash, default_string_length_count: :codepoints

config :ash_authentication_dev_users,
  ash_domains: [AshAuthenticationDevUsers.Test.Domain]
