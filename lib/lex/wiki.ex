defmodule Lex.Wiki do
  use Ash.Domain

  resources do
    resource Lex.Wiki.Page
    resource Lex.Wiki.PageDocument
  end
end
