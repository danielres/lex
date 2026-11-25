defmodule Lex.Wiki.PageDocument do
  @moduledoc false

  require Ash.Query

  alias Lex.Accounts.Membership.Checks.ActiveMember
  alias Lex.Accounts.Membership.Checks.HasPrivilege
  alias Lex.Validations.RelationshipInSpace

  use Ash.Resource,
    domain: Lex.Wiki,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "page_documents"
    repo Lex.Repo
  end

  actions do
    defaults [:read]

    create :persist do
      accept [:document_key, :page_id, :yjs_state]
      validate {RelationshipInSpace, relationship: :page}
      upsert? true
      upsert_identity :unique_page_document
      upsert_fields [:yjs_state]
    end

    create :save do
      accept [
        :content_hash,
        :document_key,
        :lexical_state,
        :page_id,
        :search_text,
        :yjs_state
      ]

      require_attributes [:content_hash, :lexical_state, :search_text]
      validate {RelationshipInSpace, relationship: :page}
      upsert? true
      upsert_identity :unique_page_document
      upsert_fields [:content_hash, :lexical_state, :search_text, :yjs_state]
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if ActiveMember
    end

    policy action([:persist, :save]) do
      authorize_if {HasPrivilege, privilege: :edit_pages}
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name Lex.PubSub
    prefix "wiki"

    publish :persist, "pages"
    publish :save, "pages"
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :document_key, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 255
      public? true
    end

    attribute :content_hash, :string do
      constraints min_length: 64, max_length: 64
      public? true
    end

    attribute :lexical_state, :map do
      public? true
    end

    attribute :search_text, :string do
      constraints allow_empty?: true
      public? true
    end

    attribute :yjs_state, :binary do
      allow_nil? false
      public? true
      sensitive? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :page, Lex.Wiki.Page do
      allow_nil? false
      attribute_public? true
    end

    belongs_to :space, Lex.Accounts.Space do
      allow_nil? false
    end
  end

  identities do
    identity :unique_page_document, [:page_id, :document_key]
  end

  def get_content(scope, page, document_key) do
    with {:ok, page_document} <- scope |> get(page, document_key) do
      case page_document do
        nil ->
          {:ok, nil}

        page_document ->
          {:ok,
           %{
             content_hash: page_document.content_hash,
             lexical_state: page_document.lexical_state
           }}
      end
    end
  end

  def save(
        scope,
        page,
        document_key,
        doc,
        %{lexical_state: lexical_state, search_text: search_text}
      ) do
    content_hash = content_hash(lexical_state)

    with {:ok, page_document} <- scope |> get(page, document_key) do
      if page_document != nil and page_document.content_hash == content_hash do
        {:ok, :unchanged}
      else
        with {:ok, yjs_state} <- Yex.encode_state_as_update(doc),
             {:ok, _page_document} <-
               scope
               |> save(
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

  def restore(scope, page, document_key, doc) do
    with {:ok, page_document} <- scope |> get(page, document_key) do
      restore(page_document, doc)
    end
  end

  def restore_collaboration(page, document_key, doc) do
    with {:ok, page_document} <- page |> get_collaboration(document_key) do
      restore(page_document, doc)
    end
  end

  def persist_collaboration(page, document_key, doc) do
    with {:ok, yjs_state} <- Yex.encode_state_as_update(doc),
         {:ok, page_document} <- page |> get_collaboration(document_key) do
      if page_document != nil and page_document.yjs_state == yjs_state do
        :ok
      else
        with {:ok, _page_document} <- page |> persist(document_key, yjs_state) do
          :ok
        end
      end
    end
  end

  defp get(scope, page, document_key) do
    __MODULE__
    |> Ash.Query.filter(page_id == ^page.id and document_key == ^document_key)
    |> Ash.read_one(scope: scope)
  end

  defp get_collaboration(page, document_key) do
    __MODULE__
    |> Ash.Query.filter(page_id == ^page.id and document_key == ^document_key)
    |> Ash.read_one(authorize?: false, tenant: page.space_id)
  end

  defp restore(nil, _doc), do: :ok
  defp restore(page_document, doc), do: Yex.apply_update(doc, page_document.yjs_state)

  defp persist(page, document_key, yjs_state) do
    __MODULE__
    |> Ash.Changeset.for_create(
      :persist,
      %{
        page_id: page.id,
        document_key: document_key,
        yjs_state: yjs_state
      },
      tenant: page.space_id
    )
    |> Ash.create(authorize?: false)
  end

  defp save(
         scope,
         page,
         document_key,
         yjs_state,
         lexical_state,
         search_text,
         content_hash
       ) do
    __MODULE__
    |> Ash.Changeset.for_create(
      :save,
      %{
        content_hash: content_hash,
        document_key: document_key,
        lexical_state: lexical_state,
        page_id: page.id,
        search_text: search_text,
        yjs_state: yjs_state
      },
      scope: scope
    )
    |> Ash.create()
  end

  defp content_hash(lexical_state) do
    lexical_state
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
