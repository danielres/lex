defmodule Lex.Topics.Topic do
  alias Lex.Accounts
  alias Lex.Accounts.Membership.Checks.ActiveMember
  alias Lex.Changes

  use Ash.Resource,
    otp_app: :lex,
    domain: Lex.Topics,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  postgres do
    table "topics"
    repo Lex.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name]
      primary? true

      change relate_actor(:author)
      change {Changes.GenerateSlug, from: :name}
    end

    update :update do
      accept [:name]
      primary? true
      require_atomic? false

      change {Changes.GenerateSlug, from: :name}
    end

    destroy :destroy do
      primary? true
      require_atomic? false
      touches_resources [Lex.Topics.Graph]

      change Lex.Topics.Changes.PruneGraph
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if ActiveMember
    end

    policy action(:create) do
      authorize_if ActiveMember
    end

    policy action(:update) do
      authorize_if ActiveMember
    end

    policy action(:destroy) do
      forbid_unless ActiveMember
      authorize_if relates_to_actor_via([:space, :owner])
      authorize_if relates_to_actor_via([:author])
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name Lex.PubSub
    prefix "topics"
    publish :create, "topics"
    publish :update, "topics"
    publish :destroy, "topics"
  end

  preparations do
    prepare build(sort: [name: :asc])
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints min_length: 2, max_length: 24
    end

    attribute :slug, :string do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :author, Accounts.User, allow_nil?: false
    belongs_to :space, Accounts.Space, allow_nil?: false
  end

  identities do
    identity :unique_slug, [:space_id, :slug] do
      field_names [:name]
      message "not available"
    end
  end
end
