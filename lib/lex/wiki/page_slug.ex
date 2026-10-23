defmodule Lex.Wiki.PageSlug do
  use Ash.Type.NewType,
    subtype_of: :string,
    constraints: [match: ~r/^[\p{L}\p{N}]+(?:-[\p{L}\p{N}]+)*$/u]

  def valid?(slug) do
    is_binary(slug) and slug == String.downcase(slug) and
      match?({:ok, _slug}, Ash.Type.cast_input(__MODULE__, slug))
  end
end
