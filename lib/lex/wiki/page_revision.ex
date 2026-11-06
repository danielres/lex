defmodule Lex.Wiki.PageRevision do
  @moduledoc false

  use Ash.Resource,
    domain: Lex.Wiki,
    data_layer: AshPostgres.DataLayer,
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "page_revisions"
    repo Lex.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :content_hash,
        :lexical_state,
        :page_id,
        :restored_from_revision_id,
        :search_text
      ]
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name Lex.PubSub
    prefix "wiki"

    publish :create, "pages"
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :content_hash, :string do
      allow_nil? false
      constraints min_length: 64, max_length: 64
      public? true
    end

    attribute :lexical_state, :map do
      allow_nil? false
      public? true
    end

    attribute :restored_from_revision_id, :uuid do
      public? true
    end

    attribute :search_text, :string do
      allow_nil? false
      constraints allow_empty?: true
      public? true
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :page, Lex.Wiki.Page do
      allow_nil? false
      attribute_public? true
    end
  end
end
