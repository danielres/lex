defmodule Lex.Wiki.PageRevisionContributor do
  @moduledoc false

  use Ash.Resource,
    domain: Lex.Wiki,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "page_revision_contributors"
    repo Lex.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:page_revision_id, :user_id]
    end
  end

  relationships do
    belongs_to :page_revision, Lex.Wiki.PageRevision do
      allow_nil? false
      primary_key? true
    end

    belongs_to :user, Lex.Accounts.User do
      allow_nil? false
      primary_key? true
    end
  end
end
