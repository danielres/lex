defmodule Lex.Wiki.Page do
  require Ash.Query

  alias Lex.Wiki.Page.Changes.SetTitleAndSlug
  alias Lex.Wiki.PageDocument
  alias Lex.Wiki.PageRevision
  alias Lex.Wiki.PageSlug
  alias Lex.Wiki.PageTitle

  use Ash.Resource,
    domain: Lex.Wiki,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "pages"
    repo Lex.Repo
  end

  code_interface do
    define :get, action: :read, get_by: [:id]
    define :list, action: :list
    define :rename, action: :rename, args: [:title]
  end

  actions do
    defaults [:read]

    read :list do
      prepare build(load: :last_updated_at, sort: :title)
    end

    create :create do
      accept [:title]

      change SetTitleAndSlug
    end

    update :rename do
      accept [:title]
      require_atomic? false

      change SetTitleAndSlug
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name Lex.PubSub
    prefix "wiki"

    publish :create, "pages"
    publish :rename, "pages"
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, Lex.Wiki.PageSlug do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  calculations do
    calculate :last_updated_at,
              :utc_datetime_usec,
              expr(
                fragment(
                  "GREATEST(?, COALESCE((SELECT MAX(updated_at) FROM page_documents WHERE page_id = ?), ?))",
                  updated_at,
                  id,
                  updated_at
                )
              )
  end

  identities do
    identity :unique_slug, [:slug],
      eager_check?: true,
      field_names: [:title],
      message: "Not available"
  end

  def ensure(title) do
    with {:ok, title} <- PageTitle.normalize(title),
         {:ok, slug} <- PageTitle.slug(title) do
      ensure_title_and_slug(title, slug)
    else
      {:error, message} -> invalid_attribute(:title, title, message)
    end
  end

  def ensure!(title), do: unwrap_or_raise!(ensure(title))

  def fetch_by_slug(slug) do
    with true <- PageSlug.valid?(slug),
         {:ok, slug} <- Ash.Type.cast_input(PageSlug, slug) do
      get_by_slug(slug)
    else
      false -> invalid_attribute(:slug, slug, "is not a valid page slug")
      :error -> invalid_attribute(:slug, slug, "is not a valid page slug")
      {:error, error} -> {:error, error}
    end
  end

  def subscribe do
    Phoenix.PubSub.subscribe(Lex.PubSub, "wiki:pages")
  end

  def list_revisions!(page) do
    PageRevision
    |> Ash.Query.filter(page_id == ^page.id)
    |> Ash.Query.sort(inserted_at: :desc, id: :desc)
    |> Ash.read!()
  end

  def get_revision(page, revision_id) do
    PageRevision
    |> Ash.Query.filter(page_id == ^page.id and id == ^revision_id)
    |> Ash.read_one()
  end

  def restore(page, document_key, doc) do
    with {:ok, page_document} <- get_page_document(page, document_key) do
      restore_page_document(page_document, doc)
    end
  end

  def set_checkpoint(page, document_key, doc) when is_binary(document_key) do
    with {:ok, yjs_state} <- Yex.encode_state_as_update(doc),
         {:ok, page_document} <- get_page_document(page, document_key) do
      if page_document != nil and page_document.yjs_state == yjs_state do
        :ok
      else
        with {:ok, _page_document} <- save_page_document(page, document_key, yjs_state) do
          :ok
        end
      end
    end
  end

  def set_checkpoint(
        page,
        %{lexical_state: lexical_state, search_text: search_text},
        restored_from_revision_id
      ) do
    content_hash = content_hash(lexical_state)

    with :ok <- validate_source_revision(page, restored_from_revision_id),
         {:ok, latest_revision} <- latest_revision(page) do
      if latest_revision != nil and latest_revision.content_hash == content_hash do
        {:ok, :unchanged}
      else
        page
        |> create_revision(
          lexical_state,
          search_text,
          content_hash,
          restored_from_revision_id
        )
        |> case do
          {:ok, _revision} -> {:ok, :saved}
          {:error, error} -> {:error, error}
        end
      end
    end
  end

  def set_checkpoint(
        page,
        document_key,
        doc,
        %{lexical_state: lexical_state, search_text: search_text}
      ) do
    content_hash = content_hash(lexical_state)

    with {:ok, page_document} <- get_page_document(page, document_key) do
      if page_document != nil and page_document.content_hash == content_hash do
        {:ok, :unchanged}
      else
        with {:ok, yjs_state} <- Yex.encode_state_as_update(doc),
             {:ok, _page_document} <-
               save_page_document_snapshot(
                 page,
                 document_key,
                 yjs_state,
                 lexical_state,
                 search_text,
                 content_hash
               ) do
          {:ok, :saved}
        end
      end
    end
  end

  defp ensure_title_and_slug(title, slug) do
    case get_by_slug(slug) do
      {:ok, nil} -> create_page(title, slug)
      {:ok, %{title: ^title} = page} -> {:ok, page}
      {:ok, _page} -> title_collision(title, slug)
      {:error, error} -> {:error, error}
    end
  end

  defp create_page(title, slug) do
    __MODULE__
    |> Ash.Changeset.for_create(:create, %{title: title})
    |> Ash.create()
    |> recover_concurrent_create(title, slug)
  end

  defp recover_concurrent_create({:ok, page}, _title, _slug), do: {:ok, page}

  defp recover_concurrent_create({:error, original_error}, title, slug) do
    case get_by_slug(slug) do
      {:ok, %{title: ^title} = page} -> {:ok, page}
      {:ok, nil} -> {:error, original_error}
      {:ok, _page} -> title_collision(title, slug)
      {:error, _error} -> {:error, original_error}
    end
  end

  defp get_by_slug(slug) do
    __MODULE__
    |> Ash.Query.filter(slug == ^slug)
    |> Ash.read_one()
  end

  defp latest_revision(page) do
    PageRevision
    |> Ash.Query.filter(page_id == ^page.id)
    |> Ash.Query.sort(inserted_at: :desc, id: :desc)
    |> Ash.read_first()
  end

  defp validate_source_revision(_page, nil), do: :ok

  defp validate_source_revision(page, revision_id) do
    case get_revision(page, revision_id) do
      {:ok, nil} -> invalid_attribute(:restored_from_revision_id, revision_id, "does not exist")
      {:ok, _revision} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp title_collision(title, slug) do
    invalid_attribute(
      :title,
      title,
      "produces the already-used slug #{inspect(slug)}"
    )
  end

  defp invalid_attribute(field, value, message) do
    error =
      Ash.Error.Changes.InvalidAttribute.exception(
        field: field,
        value: value,
        message: message
      )

    {:error, Ash.Error.to_error_class(error)}
  end

  defp unwrap_or_raise!({:ok, value}), do: value
  defp unwrap_or_raise!({:error, error}), do: raise(Ash.Error.to_error_class(error))

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

  defp save_page_document_snapshot(
         page,
         document_key,
         yjs_state,
         lexical_state,
         search_text,
         content_hash
       ) do
    PageDocument
    |> Ash.Changeset.for_create(:save_snapshot, %{
      content_hash: content_hash,
      document_key: document_key,
      lexical_state: lexical_state,
      page_id: page.id,
      search_text: search_text,
      yjs_state: yjs_state
    })
    |> Ash.create()
  end

  defp create_revision(
         page,
         lexical_state,
         search_text,
         content_hash,
         restored_from_revision_id
       ) do
    PageRevision
    |> Ash.Changeset.for_create(:create, %{
      content_hash: content_hash,
      lexical_state: lexical_state,
      page_id: page.id,
      restored_from_revision_id: restored_from_revision_id,
      search_text: search_text
    })
    |> Ash.create()
  end

  defp content_hash(lexical_state) do
    lexical_state
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
