defmodule Lex.Accounts.Space.Changes.SetSlug do
  use Ash.Resource.Change

  alias Utils.Slugify

  @impl true
  def change(changeset, _options, _context) do
    case Ash.Changeset.fetch_change(changeset, :name) do
      {:ok, name} -> set_slug(changeset, name)
      :error -> changeset
    end
  end

  defp set_slug(changeset, name) when is_binary(name) do
    slug = Slugify.generate(name)

    if slug == "" do
      Ash.Changeset.add_error(changeset,
        field: :name,
        message: "Must contain at least one letter or number"
      )
    else
      Ash.Changeset.force_change_attribute(changeset, :slug, slug)
    end
  end

  defp set_slug(changeset, _name), do: changeset
end
