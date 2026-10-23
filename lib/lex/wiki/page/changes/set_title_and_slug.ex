defmodule Lex.Wiki.Page.Changes.SetTitleAndSlug do
  use Ash.Resource.Change

  alias Lex.Wiki.PageTitle

  @impl true
  def change(changeset, _options, _context) do
    case Ash.Changeset.fetch_change(changeset, :title) do
      {:ok, title} -> set_title_and_slug(changeset, title)
      :error -> changeset
    end
  end

  defp set_title_and_slug(changeset, nil) do
    Ash.Changeset.add_error(changeset, field: :title, message: "must not be blank")
  end

  defp set_title_and_slug(changeset, title) do
    with {:ok, title} <- PageTitle.normalize(title),
         {:ok, slug} <- PageTitle.slug(title) do
      changeset
      |> Ash.Changeset.force_change_attribute(:title, title)
      |> Ash.Changeset.force_change_attribute(:slug, slug)
    else
      {:error, message} -> Ash.Changeset.add_error(changeset, field: :title, message: message)
    end
  end
end
