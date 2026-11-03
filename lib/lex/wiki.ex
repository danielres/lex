defmodule Lex.Wiki do
  use Ash.Domain, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Lex.Wiki.Page
    resource Lex.Wiki.PageDocument
    resource Lex.Wiki.PageRevision
  end
end
