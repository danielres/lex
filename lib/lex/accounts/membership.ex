defmodule Lex.Accounts.Membership do
  require Ash.Query

  alias Lex.Accounts.Membership.Changes.SetIdentity
  alias Lex.Accounts.Membership.Checks.ActiveMember
  alias Lex.Accounts.Membership.Checks.CanSetPrivileges
  alias Lex.Accounts.Membership.Checks.HasPrivilege
  alias Lex.Accounts.Membership.Validations.OwnerMustRemainMember
  alias Lex.Accounts.Privilege
  alias Lex.Accounts.Space
  alias Lex.Accounts.User

  use Ash.Resource,
    otp_app: :lex,
    domain: Lex.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

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

    read :current_user do
      multitenancy :bypass

      filter expr(user_id == ^actor(:id) and status in [:active, :invited])
      prepare build(load: :space, sort: :inserted_at)
    end

    read :active do
      filter expr(status == :active)
      prepare build(load: :user, sort: [:display_name, :inserted_at])
    end

    read :pending do
      filter expr(status == :invited)
      prepare build(load: :user, sort: :inserted_at)
    end

    read :declined do
      filter expr(status == :declined)
      prepare build(load: :user, sort: :inserted_at)
    end

    read :disabled do
      filter expr(status == :disabled)
      prepare build(load: :user, sort: :inserted_at)
    end

    read :all do
      prepare build(load: :user, sort: [:status, :display_name, :inserted_at])
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
      change set_attribute(:status, :declined)
    end

    update :reinvite do
      require_atomic? false

      validate attribute_in(:status, [:declined, :disabled])
      change set_attribute(:status, :invited)
    end

    update :disable do
      require_atomic? false

      validate attribute_equals(:status, :active)
      validate OwnerMustRemainMember
      change set_attribute(:status, :disabled)
    end

    update :set_privileges do
      accept [:privileges]
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.update_change(changeset, :privileges, fn privileges ->
          privileges |> Enum.uniq() |> Enum.sort()
        end)
      end
    end
  end

  policies do
    policy action(:current_user) do
      authorize_if actor_present()
    end

    bypass action(:read) do
      authorize_if expr(user_id == ^actor(:id))
      authorize_if {HasPrivilege, privilege: :manage_members}
    end

    policy action(:read) do
      authorize_if {HasPrivilege, privilege: :manage_privileges}
      forbid_if expr(status == :declined)
    end

    policy action(:active) do
      authorize_if ActiveMember
    end

    policy action(:pending) do
      authorize_if {HasPrivilege, privilege: :manage_members}
      authorize_if {HasPrivilege, privilege: :manage_privileges}
      authorize_if {HasPrivilege, privilege: :view_pending_memberships}
    end

    policy action(:disabled) do
      authorize_if {HasPrivilege, privilege: :manage_members}
      authorize_if {HasPrivilege, privilege: :manage_privileges}
      authorize_if {HasPrivilege, privilege: :view_disabled_memberships}
    end

    policy action([:all, :declined]) do
      authorize_if {HasPrivilege, privilege: :manage_members}
    end

    policy action([:accept, :decline]) do
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action([:disable, :invite, :reinvite]) do
      authorize_if {HasPrivilege, privilege: :manage_members}
    end

    policy action(:set_privileges) do
      authorize_if CanSetPrivileges
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
      constraints one_of: [:invited, :active, :declined, :disabled]
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

    attribute :privileges, {:array, Privilege} do
      allow_nil? false
      default [:edit_pages]
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

  def invite(scope, user_id) do
    __MODULE__
    |> Ash.Changeset.for_create(:invite, %{user_id: user_id}, scope: scope)
    |> Ash.create()
  end

  def accept(scope, membership, display_name) do
    membership
    |> Ash.Changeset.for_update(:accept, %{display_name: display_name}, scope: scope)
    |> Ash.update()
  end

  def decline(scope, membership) do
    membership
    |> Ash.Changeset.for_update(:decline, %{}, scope: scope)
    |> Ash.update()
  end

  def disable(scope, membership) do
    membership
    |> Ash.Changeset.for_update(:disable, %{}, scope: scope)
    |> Ash.update()
  end

  def reinvite(scope, membership) do
    membership
    |> Ash.Changeset.for_update(:reinvite, %{}, scope: scope)
    |> Ash.update()
  end

  def set_privileges(scope, membership, privileges) do
    membership
    |> Ash.Changeset.for_update(:set_privileges, %{privileges: privileges}, scope: scope)
    |> Ash.update()
  end

  def get(%Lex.Scope{user: %User{id: user_id}} = scope) do
    __MODULE__
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.read_one(scope: scope)
  end

  def get(%Lex.Scope{} = scope, membership_id) do
    __MODULE__ |> Ash.get(membership_id, scope: scope)
  end

  def list(%Lex.Scope{} = scope) do
    scope
    |> query()
    |> Ash.read(scope: scope)
  end

  def list!(%Lex.Scope{} = scope) do
    scope
    |> query()
    |> Ash.read!(scope: scope)
  end

  def list(%Lex.Scope{} = scope, selection) do
    scope
    |> query(selection)
    |> Ash.read(scope: scope)
  end

  def list!(%Lex.Scope{} = scope, selection) do
    scope
    |> query(selection)
    |> Ash.read!(scope: scope)
  end

  def list_invitable_users!(%Lex.Scope{} = scope) do
    membership_user_ids =
      scope
      |> list!(:all)
      |> Enum.map(& &1.user_id)

    User
    |> Ash.Query.filter(id not in ^membership_user_ids)
    |> Ash.Query.sort(:display_name)
    |> Ash.read!(scope: scope)
  end

  defp query(%Lex.Scope{} = scope) do
    __MODULE__ |> Ash.Query.for_read(:current_user, %{}, scope: scope)
  end

  defp query(%Lex.Scope{space: %Space{}} = scope, selection)
       when selection in [:active, :all, :declined, :disabled, :pending] do
    __MODULE__ |> Ash.Query.for_read(selection, %{}, scope: scope)
  end
end
