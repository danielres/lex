defmodule Lex.Accounts do
  use Ash.Domain,
    otp_app: :lex,
    extensions: [AshPhoenix]

  resources do
    resource Lex.Accounts.Space
  end
end
