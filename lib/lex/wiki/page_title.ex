defmodule Lex.Wiki.PageTitle do
  @separator ~r/[^\p{L}\p{N}]+/u
  @whitespace ~r/\s+/u

  def normalize(title) when is_binary(title) do
    title =
      title
      |> String.normalize(:nfc)
      |> String.trim()
      |> String.replace(@whitespace, " ")

    if title == "" do
      {:error, "must not be blank"}
    else
      {:ok, title}
    end
  end

  def normalize(_title), do: {:error, "must be a string"}

  def slug(title) do
    with {:ok, title} <- normalize(title) do
      slug =
        title
        |> String.downcase()
        |> String.replace(@separator, "-")
        |> String.trim("-")

      if slug == "" do
        {:error, "must contain at least one letter or number"}
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
