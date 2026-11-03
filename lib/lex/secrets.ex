defmodule Lex.Secrets do
  use AshAuthentication.Secret

  def secret_for([:authentication, :tokens, :signing_secret], Lex.Accounts.User, _opts, _context) do
    Application.fetch_env(:lex, :token_signing_secret)
  end
end
