defmodule Lex.Accounts.MembershipTest do
  use Lex.DataCase

  alias Lex.Accounts
  alias Lex.Accounts.Membership
  alias Lex.Accounts.Space
  alias Lex.Scope

  setup do
    current_user = create_user()
    scope = %Scope{current_user: current_user}
    space = Space.create!(%{name: "Test Space"}, scope: scope)
    scope = %{scope | space_id: space.id}

    {:ok, current_user: current_user, scope: scope, space: space}
  end

  test "space creation records its owner and creates an invited membership", %{
    current_user: current_user,
    scope: scope,
    space: space
  } do
    assert space.owner_id == current_user.id
    assert {:ok, membership} = scope |> Accounts.get_membership(current_user)
    assert membership.status == :invited
    assert membership.display_name == nil
    assert membership.slug == nil
  end

  test "accepting an invitation establishes an immutable normalized identity", %{
    scope: scope
  } do
    member = create_user("Member")
    {:ok, membership} = scope |> Accounts.invite_membership(member)

    assert {:ok, membership} =
             scope |> Accounts.accept_membership(membership, "  Téam   Member  ")

    assert membership.status == :active
    assert membership.display_name == "Téam Member"
    assert membership.slug == "team-member"

    assert {:ok, membership} = scope |> Accounts.deactivate_membership(membership)
    assert {:ok, membership} = scope |> Accounts.reinvite_membership(membership)
    assert {:ok, membership} = scope |> Accounts.accept_membership(membership, nil)

    assert membership.status == :active
    assert membership.display_name == "Téam Member"
    assert membership.slug == "team-member"
  end

  test "declining an invitation preserves an inactive membership", %{
    scope: scope
  } do
    member = create_user("Member")
    {:ok, membership} = scope |> Accounts.invite_membership(member)

    assert {:ok, membership} = scope |> Accounts.decline_membership(membership)
    assert membership.status == :inactive
  end

  test "the owner cannot decline or deactivate their membership", %{
    current_user: current_user,
    scope: scope
  } do
    {:ok, membership} = scope |> Accounts.get_membership(current_user)

    assert {:error, _error} = scope |> Accounts.decline_membership(membership)
    assert {:ok, membership} = scope |> Accounts.accept_membership(membership, "Owner")
    assert {:error, _error} = scope |> Accounts.deactivate_membership(membership)
  end

  test "member slugs are unique within a space", %{scope: scope} do
    first_user = create_user("First User")
    second_user = create_user("Second User")

    assert {:ok, first_membership} = scope |> Accounts.invite_membership(first_user)
    assert {:ok, second_membership} = scope |> Accounts.invite_membership(second_user)

    assert {:ok, _membership} =
             scope |> Accounts.accept_membership(first_membership, "Same Name")

    assert {:error, _error} =
             scope |> Accounts.accept_membership(second_membership, "Same Name")
  end

  test "memberships are isolated by space", %{current_user: current_user, scope: scope} do
    other_scope = %Scope{current_user: current_user}
    other_space = Space.create!(%{name: "Other Space"}, scope: other_scope)
    other_scope = %{other_scope | space_id: other_space.id}

    assert {:ok, first_membership} = scope |> Accounts.get_membership(current_user)
    assert {:ok, second_membership} = other_scope |> Accounts.get_membership(current_user)

    refute first_membership.id == second_membership.id
    assert first_membership.space_id == scope.space_id
    assert second_membership.space_id == other_scope.space_id
  end

  test "invalid lifecycle transitions are rejected", %{
    current_user: current_user,
    scope: scope
  } do
    {:ok, membership} = scope |> Accounts.get_membership(current_user)

    assert {:error, _error} = scope |> Accounts.deactivate_membership(membership)
    assert {:ok, membership} = scope |> Accounts.accept_membership(membership, "Member")
    assert {:error, _error} = scope |> Accounts.decline_membership(membership)
  end

  test "a first acceptance requires a usable display name", %{
    current_user: current_user,
    scope: scope
  } do
    {:ok, membership} = scope |> Accounts.get_membership(current_user)

    assert {:error, _error} = scope |> Accounts.accept_membership(membership, nil)
    assert {:error, _error} = scope |> Accounts.accept_membership(membership, "---")

    assert {:ok, reloaded} = Ash.get(Membership, membership.id, scope: scope)
    assert reloaded.status == :invited
  end
end
