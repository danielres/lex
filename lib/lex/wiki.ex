defmodule Lex.Wiki do
  use Ash.Domain

  resources do
    resource Lex.Wiki.Page do
      define :ensure_page, action: :ensure, args: [:slug]
    end
  end
end
