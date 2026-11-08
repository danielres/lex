defmodule Lex.Accounts do
  require Ash.Query

  alias Lex.Accounts.Membership
  alias Lex.Accounts.Membership.Access
  alias Lex.Accounts.Privilege
  alias Lex.Accounts.Space
  alias Lex.Accounts.User

  use Ash.Domain,
    otp_app: :lex,
    extensions: [AshAdmin.Domain, AshPhoenix]

  admin do
    show? true
  end

  resources do
    resource Lex.Accounts.Membership
    resource Lex.Accounts.Space
    resource Lex.Accounts.Token
    resource Lex.Accounts.User
  end

  def available_privileges, do: Privilege.values()

  def invite_membership(scope, %User{} = user) do
    Membership
    |> Ash.Changeset.for_create(:invite, %{user_id: user.id}, scope: scope)
    |> Ash.create()
  end

  def get_user(%Lex.Scope{} = scope, user_id) do
    User |> Ash.get(user_id, scope: scope)
  end

  def list_invitable_users!(%Lex.Scope{} = scope) do
    membership_user_ids =
      scope
      |> list_memberships!(:all)
      |> Enum.map(& &1.user_id)

    User
    |> Ash.Query.filter(id not in ^membership_user_ids)
    |> Ash.Query.sort(:display_name)
    |> Ash.read!(scope: scope)
  end

  def accept_membership(scope, %Membership{} = membership, display_name) do
    membership
    |> Ash.Changeset.for_update(:accept, %{display_name: display_name}, scope: scope)
    |> Ash.update()
  end

  def decline_membership(scope, %Membership{} = membership) do
    membership
    |> Ash.Changeset.for_update(:decline, %{}, scope: scope)
    |> Ash.update()
  end

  def reinvite_membership(scope, %Membership{} = membership) do
    membership
    |> Ash.Changeset.for_update(:reinvite, %{}, scope: scope)
    |> Ash.update()
  end

  def disable_membership(scope, %Membership{} = membership) do
    membership
    |> Ash.Changeset.for_update(:disable, %{}, scope: scope)
    |> Ash.update()
  end

  def set_membership_privileges(scope, %Membership{} = membership, privileges) do
    membership
    |> Ash.Changeset.for_update(:set_privileges, %{privileges: privileges}, scope: scope)
    |> Ash.update()
  end

  def has_privilege?(%Lex.Scope{} = scope, privilege) do
    Access.has_privilege?(scope, privilege)
  end

  def effective_privileges(%Lex.Scope{} = scope) do
    Access.effective_privileges(scope)
  end

  def get_membership(%Lex.Scope{user: %User{id: user_id}} = scope) do
    Membership
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.read_one(scope: scope)
  end

  def get_membership(scope, membership_id) do
    Membership |> Ash.get(membership_id, scope: scope)
  end

  def list_memberships(%Lex.Scope{} = scope) do
    scope
    |> memberships_query()
    |> Ash.read(scope: scope)
  end

  def list_memberships!(%Lex.Scope{} = scope) do
    scope
    |> memberships_query()
    |> Ash.read!(scope: scope)
  end

  def list_memberships(%Lex.Scope{} = scope, selection) do
    scope
    |> memberships_query(selection)
    |> Ash.read(scope: scope)
  end

  def list_memberships!(%Lex.Scope{} = scope, selection) do
    scope
    |> memberships_query(selection)
    |> Ash.read!(scope: scope)
  end

  defp memberships_query(%Lex.Scope{} = scope) do
    Membership |> Ash.Query.for_read(:current_user, %{}, scope: scope)
  end

  defp memberships_query(%Lex.Scope{space: %Space{}} = scope, selection)
       when selection in [:active, :all, :declined, :disabled, :pending] do
    Membership |> Ash.Query.for_read(selection, %{}, scope: scope)
  end
end
