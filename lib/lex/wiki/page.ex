defmodule Lex.Wiki.Page do
  require Ash.Query

  alias Lex.Wiki.PageDocument
  alias Lex.Wiki.PageSlug
  alias Lex.Wiki.PageTitle

  use Ash.Resource,
    domain: Lex.Wiki,
    data_layer: AshSqlite.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  sqlite do
    table "pages"
    repo Lex.Repo
  end

  code_interface do
    define :get, action: :read, get_by: [:id]
    define :list, action: :list
  end

  actions do
    defaults [:read]

    read :list do
      prepare build(sort: :title)
    end

    create :create_page do
      accept [:title, :slug]
    end

    update :rename_page do
      accept [:title, :slug]
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name Lex.PubSub
    prefix "wiki"

    publish :rename_page, "pages"
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

  identities do
    identity :unique_slug, [:slug]
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

  def open(slug) do
    with true <- PageSlug.valid?(slug),
         {:ok, slug} <- Ash.Type.cast_input(PageSlug, slug) do
      case get_by_slug(slug) do
        {:ok, nil} -> ensure(PageTitle.from_slug(slug))
        {:ok, page} -> {:ok, page}
        {:error, error} -> {:error, error}
      end
    else
      false -> invalid_attribute(:slug, slug, "is not a valid page slug")
      :error -> invalid_attribute(:slug, slug, "is not a valid page slug")
      {:error, error} -> {:error, error}
    end
  end

  def open!(slug), do: unwrap_or_raise!(open(slug))

  def rename(page, title) do
    with {:ok, title} <- PageTitle.normalize(title),
         {:ok, slug} <- PageTitle.slug(title),
         :ok <- ensure_slug_available(slug, page.id) do
      page
      |> Ash.Changeset.for_update(:rename_page, %{title: title, slug: slug})
      |> Ash.update()
    else
      {:error, message} when is_binary(message) -> invalid_attribute(:title, title, message)
      {:error, error} -> {:error, error}
    end
  end

  def rename!(page, title), do: unwrap_or_raise!(rename(page, title))

  def subscribe do
    Phoenix.PubSub.subscribe(Lex.PubSub, "wiki:pages")
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
    |> Ash.Changeset.for_create(:create_page, %{title: title, slug: slug})
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

  defp ensure_slug_available(slug, page_id) do
    case get_by_slug(slug) do
      {:ok, nil} -> :ok
      {:ok, %{id: ^page_id}} -> :ok
      {:ok, _page} -> {:error, "produces a slug already used by another page"}
      {:error, error} -> {:error, error}
    end
  end

  defp get_by_slug(slug) do
    __MODULE__
    |> Ash.Query.filter(slug == ^slug)
    |> Ash.read_one()
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
end
