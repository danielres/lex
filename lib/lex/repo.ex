defmodule Lex.Repo do
  use AshPostgres.Repo,
    otp_app: :lex

  @impl true
  def installed_extensions, do: ["ash-functions"]

  @impl true
  def min_pg_version, do: %Version{major: 17, minor: 9, patch: 0}
end
