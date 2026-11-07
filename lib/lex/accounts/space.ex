defmodule Lex.Accounts.Space do
  alias Lex.Accounts.Membership
  alias Lex.Accounts.Space.Changes.CreateOwnerMembership
  alias Lex.Accounts.Space.Changes.SetSlug
  alias Lex.Accounts.User
  alias Lex.Wiki.Page

  use Ash.Resource,
    otp_app: :lex,
    domain: Lex.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "spaces"
    repo Lex.Repo
  end

  code_interface do
    define :create, action: :create
    define :get_by_slug, action: :read, get_by: [:slug]
    define :list, action: :list
  end

  actions do
    defaults [
      :read,
      :destroy,
      update: :*
    ]

    create :create do
      accept [:name, :description]

      change relate_actor(:owner)
      change SetSlug
      change CreateOwnerMembership
    end

    read :list do
      prepare build(sort: :name)
    end
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :slug, :string do
      public? true
      allow_nil? false
    end

    attribute :description, :string do
      public? true
      allow_nil? true
    end
  end

  relationships do
    belongs_to :owner, User do
      allow_nil? false
    end

    has_many :memberships, Membership do
      destination_attribute :space_id
      default_sort inserted_at: :asc
    end

    has_many :pages, Page do
      destination_attribute :space_id
      default_sort inserted_at: :asc
    end
  end

  identities do
    identity :unique_slug, [:slug],
      eager_check?: true,
      field_names: [:name],
      message: "Not available"
  end
end
