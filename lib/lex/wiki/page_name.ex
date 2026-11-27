defmodule Lex.Wiki.PageName do
  alias Utils.Slugify

  @whitespace ~r/\s+/u

  def normalize(name) when is_binary(name) do
    name =
      name
      |> String.normalize(:nfc)
      |> String.trim()
      |> String.replace(@whitespace, " ")
      |> capitalize_first()

    case String.length(name) do
      0 -> {:error, "Cannot be empty"}
      length when length < 3 -> {:error, "Min 3 chars"}
      length when length > 40 -> {:error, "Max 40 chars"}
      _length -> {:ok, name}
    end
  end

  def normalize(_title), do: {:error, "Must be a string"}

  def slug(name) do
    with {:ok, name} <- normalize(name) do
      slug = Slugify.generate(name)

      if slug == "" do
        {:error, "Must contain at least one letter or number"}
      else
        {:ok, slug}
      end
    end
  end

  def from_slug(slug) do
    slug
    |> String.replace("-", " ")
    |> capitalize_first()
  end

  defp capitalize_first(name) do
    case String.next_grapheme(name) do
      {first, rest} ->
        capitalized = String.upcase(first) <> rest

        if Slugify.generate(capitalized) == Slugify.generate(name) do
          capitalized
        else
          name
        end

      nil ->
        name
    end
  end
end
