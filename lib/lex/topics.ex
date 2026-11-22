defmodule Lex.Topics do
  use Ash.Domain, otp_app: :lex, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Lex.Topics.Graph
    resource Lex.Topics.Tagging
    resource Lex.Topics.Topic
  end
end
