defmodule Lex.Accounts do
  require Ash.Query

  alias Lex.Accounts.Membership
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

  def invite_membership(scope, %User{} = user) do
    Membership
    |> Ash.Changeset.for_create(:invite, %{user_id: user.id}, scope: scope)
    |> Ash.create()
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

  def deactivate_membership(scope, %Membership{} = membership) do
    membership
    |> Ash.Changeset.for_update(:deactivate, %{}, scope: scope)
    |> Ash.update()
  end

  def set_membership_privileges(scope, %Membership{} = membership, privileges) do
    membership
    |> Ash.Changeset.for_update(:set_privileges, %{privileges: privileges}, scope: scope)
    |> Ash.update()
  end

  def get_membership(scope, %User{} = user) do
    Membership
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.read_one(scope: scope)
  end

  def list_memberships!(scope) do
    Membership
    |> Ash.Query.for_read(:for_user, %{}, scope: scope)
    |> Ash.read!(scope: scope)
  end
end
