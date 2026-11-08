defmodule Lex.Wiki.PageRevision do
  @moduledoc false

  alias Lex.Accounts.Membership.Checks.ActiveMember
  alias Lex.Accounts.Membership.Checks.HasPrivilege

  use Ash.Resource,
    domain: Lex.Wiki,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "page_revisions"
    repo Lex.Repo
  end

  actions do
    defaults [:read]

    create :create do
      argument :contributor_ids, {:array, :uuid} do
        allow_nil? false
        default []
      end

      accept [
        :content_hash,
        :lexical_state,
        :page_id,
        :restored_from_revision_id,
        :search_text
      ]

      change relate_actor(:saved_by)
      change manage_relationship(:contributor_ids, :contributors, type: :append)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if ActiveMember
    end

    policy action(:create) do
      authorize_if {HasPrivilege, privilege: :edit_pages}
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
    belongs_to :saved_by, Lex.Accounts.User do
      allow_nil? false
    end

    belongs_to :page, Lex.Wiki.Page do
      allow_nil? false
      attribute_public? true
    end

    many_to_many :contributors, Lex.Accounts.User do
      through Lex.Wiki.PageRevisionContributor
      source_attribute_on_join_resource :page_revision_id
      destination_attribute_on_join_resource :user_id
      sort display_name: :asc
    end
  end
end
