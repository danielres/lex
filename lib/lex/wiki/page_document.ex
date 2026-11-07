defmodule Lex.Wiki.PageDocument do
  @moduledoc false

  use Ash.Resource,
    domain: Lex.Wiki,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "page_documents"
    repo Lex.Repo
  end

  actions do
    defaults [:read]

    create :save do
      accept [:document_key, :page_id, :yjs_state]
      upsert? true
      upsert_identity :unique_page_document
      upsert_fields [:yjs_state]
    end

    create :save_snapshot do
      accept [
        :content_hash,
        :document_key,
        :lexical_state,
        :page_id,
        :search_text,
        :yjs_state
      ]

      require_attributes [:content_hash, :lexical_state, :search_text]
      upsert? true
      upsert_identity :unique_page_document
      upsert_fields [:content_hash, :lexical_state, :search_text, :yjs_state]
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name Lex.PubSub
    prefix "wiki"

    publish :save, "pages"
    publish :save_snapshot, "pages"
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
  end

  identities do
    identity :unique_page_document, [:page_id, :document_key]
  end
end
