defmodule Lex.Repo do
  use AshPostgres.Repo,
    otp_app: :lex

  @impl true
  def installed_extensions, do: ["ash-functions", "citext"]

  @impl true
  def min_pg_version, do: %Version{major: 17, minor: 9, patch: 0}
  # Don't open unnecessary transactions
  # will default to `false` in 4.0
  @impl true
  def prefer_transaction? do
    false
  end
end
