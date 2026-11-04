import Config
config :ash_authentication_development, enabled: true
config :lex, token_signing_secret: "L+eXyy1VvJh1SQ5/8l73Yj5Jf7eux7Ur"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
database_connection =
  case System.get_env("PGHOST") do
    "/" <> _path = socket_dir -> [socket_dir: socket_dir]
    hostname when is_binary(hostname) -> [hostname: hostname]
    nil -> [hostname: "localhost"]
  end

config :lex,
       Lex.Repo,
       Keyword.merge(
         [
           port: String.to_integer(System.get_env("PGPORT", "5432")),
           username: "postgres",
           password: "postgres",
           database: "lex_test#{System.get_env("MIX_TEST_PARTITION")}",
           pool: Ecto.Adapters.SQL.Sandbox,
           pool_size: System.schedulers_online() * 2
         ],
         database_connection
       )

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :lex, LexWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "RgAREPZj2KviQJEcWti168m+eD1FFs7OufYEmQooeHq4Qon42VBLfVxH26EN6eyk",
  server: false

# In test we don't send emails
config :lex, Lex.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
