defmodule Lex.Wiki.DocumentKey do
  use Ash.Type.NewType,
    subtype_of: :string,
    constraints: [min_length: 1, max_length: 255]
end
