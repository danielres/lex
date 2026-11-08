defmodule Lex.Accounts do
  use Ash.Domain,
    otp_app: :lex,
    extensions: [AshAdmin.Domain, AshPhoenix]

  admin do
    show? true
  end

  resources do
    resource Lex.Accounts.Membership
    resource Lex.Accounts.Space
    resource Lex.Accounts.Token
    resource Lex.Accounts.User
  end
end
