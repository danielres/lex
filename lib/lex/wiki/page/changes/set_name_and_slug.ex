defmodule Lex.Wiki.Page.Changes.SetNameAndSlug do
  use Ash.Resource.Change

  alias Lex.Wiki.PageName

  @impl true
  def change(changeset, _options, _context) do
    case Ash.Changeset.fetch_change(changeset, :name) do
      {:ok, name} -> set_name_and_slug(changeset, name)
      :error -> changeset
    end
  end

  defp set_name_and_slug(changeset, nil) do
    Ash.Changeset.add_error(changeset, field: :name, message: "must not be blank")
  end

  defp set_name_and_slug(changeset, name) do
    with {:ok, name} <- PageName.normalize(name),
         {:ok, slug} <- PageName.slug(name) do
      changeset
      |> Ash.Changeset.force_change_attribute(:name, name)
      |> Ash.Changeset.force_change_attribute(:slug, slug)
    else
      {:error, message} -> Ash.Changeset.add_error(changeset, field: :name, message: message)
    end
  end
end
