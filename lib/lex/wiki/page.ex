defmodule Lex.Wiki.Page do
  use Ash.Resource,
    domain: Lex.Wiki,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "pages"
    repo Lex.Repo
  end

  actions do
    defaults [:read]

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
end
