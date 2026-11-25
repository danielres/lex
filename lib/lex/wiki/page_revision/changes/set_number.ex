defmodule Lex.Wiki.PageRevision.Changes.SetNumber do
  use Ash.Resource.Change

  require Ash.Query

  alias Lex.Wiki.Page
  alias Lex.Wiki.PageRevision

  @impl true
  def change(changeset, _options, context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      page_id = Ash.Changeset.get_attribute(changeset, :page_id)

      with {:ok, _page} <- lock_page(page_id, context.tenant),
           {:ok, latest_number} <- latest_number(page_id, context.tenant) do
        number = (latest_number || 0) + 1

        changeset |> Ash.Changeset.force_change_attribute(:number, number)
      else
        {:error, error} -> Ash.Changeset.add_error(changeset, error)
      end
    end)
  end

  defp lock_page(page_id, tenant) do
    Ash.get(Page, page_id,
      authorize?: false,
      lock: :for_update,
      not_found_error?: true,
      tenant: tenant
    )
  end

  defp latest_number(page_id, tenant) do
    PageRevision
    |> Ash.Query.filter(page_id == ^page_id)
    |> Ash.max(:number, authorize?: false, tenant: tenant)
  end
end
