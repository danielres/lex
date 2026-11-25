defmodule Lex.Wiki.PageTitle do
  alias Utils.Slugify

  @whitespace ~r/\s+/u

  def normalize(title) when is_binary(title) do
    title =
      title
      |> String.normalize(:nfc)
      |> String.trim()
      |> String.replace(@whitespace, " ")
      |> capitalize_first()

    case String.length(title) do
      0 -> {:error, "Cannot be empty"}
      length when length < 3 -> {:error, "Min 3 chars"}
      length when length > 40 -> {:error, "Max 40 chars"}
      _length -> {:ok, title}
    end
  end

  def normalize(_title), do: {:error, "Must be a string"}

  def slug(title) do
    with {:ok, title} <- normalize(title) do
      slug = Slugify.generate(title)

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

  defp capitalize_first(title) do
    case String.next_grapheme(title) do
      {first, rest} -> String.upcase(first) <> rest
      nil -> title
    end
  end
end
