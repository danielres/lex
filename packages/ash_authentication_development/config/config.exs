import Config

config :ash, default_string_length_count: :codepoints

config :ash_authentication_development,
  ash_domains: [AshAuthenticationDevelopment.Test.Domain]
