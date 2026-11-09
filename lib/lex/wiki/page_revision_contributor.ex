defmodule Lex.Wiki.PageRevisionContributor do
  @moduledoc false

  alias Lex.Accounts.Membership.Checks.ActiveMember
  alias Lex.Accounts.Membership.Checks.HasPrivilege
  alias Lex.Wiki.Validations.ParentInSpace

  use Ash.Resource,
    domain: Lex.Wiki,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "page_revision_contributors"
    repo Lex.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:page_revision_id, :user_id]
      validate {ParentInSpace, relationship: :page_revision}
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

  multitenancy do
    strategy :attribute
    attribute :space_id
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

    belongs_to :space, Lex.Accounts.Space do
      allow_nil? false
    end
  end
end
