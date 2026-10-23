defmodule Lex.Wiki.PageTitle do
  @separator ~r/[^\p{L}\p{N}]+/u
  @whitespace ~r/\s+/u

  def normalize(title) when is_binary(title) do
    title =
      title
      |> String.normalize(:nfc)
      |> String.trim()
      |> String.replace(@whitespace, " ")

    case String.length(title) do
      0 -> {:error, "Cannot be empty"}
      length when length < 3 -> {:error, "Min 3 chars"}
      length when length > 20 -> {:error, "Max 40 chars"}
      _length -> {:ok, title}
    end
  end

  def normalize(_title), do: {:error, "Must be a string"}

  def slug(title) do
    with {:ok, title} <- normalize(title) do
      slug =
        title
        |> String.downcase()
        |> String.replace(@separator, "-")
        |> String.trim("-")

      if slug == "" do
        {:error, "Must contain at least one letter or number"}
      else
        {:ok, slug}
      end
    end
  end

  def from_slug(slug) do
    slug
    |> String.split("-", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
