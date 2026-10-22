defmodule Lex.Wiki.Page do
  require Ash.Query

  alias Lex.Wiki.PageDocument

  use Ash.Resource,
    domain: Lex.Wiki,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "pages"
    repo Lex.Repo
  end

  code_interface do
    define :ensure, action: :ensure, args: [:slug]
    define :get, action: :read, get_by: [:id]
    define :list, action: :list
  end

  actions do
    defaults [:read]

    read :list do
      prepare build(sort: :slug)
    end

    create :ensure do
      accept [:slug]
      upsert? true
      upsert_identity :unique_slug
      upsert_fields []
      return_skipped_upsert? true
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :slug, Lex.Wiki.PageSlug do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_slug, [:slug]
  end

  def restore(page, document_key, doc) do
    with {:ok, page_document} <- get_page_document(page, document_key) do
      restore_page_document(page_document, doc)
    end
  end

  def set_checkpoint(page, document_key, doc) do
    with {:ok, yjs_state} <- Yex.encode_state_as_update(doc),
         {:ok, _page_document} <- save_page_document(page, document_key, yjs_state) do
      :ok
    end
  end

  defp get_page_document(page, document_key) do
    page_id = page.id

    PageDocument
    |> Ash.Query.filter(page_id == ^page_id and document_key == ^document_key)
    |> Ash.read_one()
  end

  defp restore_page_document(nil, _doc), do: :ok

  defp restore_page_document(page_document, doc) do
    Yex.apply_update(doc, page_document.yjs_state)
  end

  defp save_page_document(page, document_key, yjs_state) do
    PageDocument
    |> Ash.Changeset.for_create(:save, %{
      page_id: page.id,
      document_key: document_key,
      yjs_state: yjs_state
    })
    |> Ash.create()
  end
end
