defmodule Lex.Accounts.Space do
  alias Lex.Accounts.Space.Changes.SetSlug
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
      change SetSlug
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
