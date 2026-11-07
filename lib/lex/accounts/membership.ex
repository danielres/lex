defmodule Lex.Accounts.Membership do
  alias Lex.Accounts.Membership.Changes.SetIdentity
  alias Lex.Accounts.Membership.Validations.OwnerMustRemainMember

  use Ash.Resource,
    otp_app: :lex,
    domain: Lex.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "memberships"
    repo Lex.Repo

    references do
      reference :space, on_delete: :delete
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    read :for_user do
      multitenancy :bypass

      filter expr(user_id == ^actor(:id) and status in [:active, :invited])
      prepare build(load: :space, sort: :inserted_at)
    end

    create :invite do
      accept [:user_id]
    end

    update :accept do
      require_atomic? false

      argument :display_name, :string

      validate attribute_equals(:status, :invited)
      change SetIdentity
      change set_attribute(:status, :active)
    end

    update :decline do
      require_atomic? false

      validate attribute_equals(:status, :invited)
      validate OwnerMustRemainMember
      change set_attribute(:status, :inactive)
    end

    update :reinvite do
      require_atomic? false

      validate attribute_equals(:status, :inactive)
      change set_attribute(:status, :invited)
    end

    update :deactivate do
      require_atomic? false

      validate attribute_equals(:status, :active)
      validate OwnerMustRemainMember
      change set_attribute(:status, :inactive)
    end
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :status, :atom do
      allow_nil? false
      constraints one_of: [:invited, :active, :inactive]
      default :invited
      public? true
    end

    attribute :display_name, :string do
      constraints min_length: 1, max_length: 80
      public? true
    end

    attribute :slug, :string do
      constraints min_length: 1, max_length: 80
      public? true
    end
  end

  relationships do
    belongs_to :space, Lex.Accounts.Space do
      allow_nil? false
    end

    belongs_to :user, Lex.Accounts.User do
      allow_nil? false
      attribute_public? true
    end
  end

  identities do
    identity :unique_space_user, [:user_id]

    identity :unique_space_slug, [:slug],
      eager_check?: true,
      field_names: [:display_name],
      message: "Not available"
  end
end
