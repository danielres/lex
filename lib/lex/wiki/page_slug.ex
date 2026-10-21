defmodule Lex.Wiki.PageSlug do
  use Ash.Type.NewType,
    subtype_of: :string,
    constraints: [match: ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/]

  def valid?(slug) do
    match?({:ok, _slug}, Ash.Type.cast_input(__MODULE__, slug))
  end
end
