defmodule Lex.Accounts.MembershipTest do
  use Lex.DataCase

  alias Lex.Accounts.Membership
  alias Lex.Accounts.Space
  alias Lex.Scope

  setup do
    user = create_user()
    scope = %Scope{user: user}
    space = Space.create!(%{name: "Test Space"}, scope: scope)
    scope = %{scope | space: space}

    {:ok, scope: scope}
  end

  test "space creation records its owner and creates an invited membership", %{scope: scope} do
    assert scope.space.owner_id == scope.user.id
    assert {:ok, membership} = scope |> Membership.get()
    assert membership.status == :invited
    assert membership.display_name == nil
    assert membership.slug == nil
    assert membership.privileges == [:edit_pages]
  end

  test "accepting an invitation establishes an immutable normalized identity", %{scope: scope} do
    scope = scope |> activate_owner()
    member = create_user("Member")
    {:ok, membership} = scope |> Membership.invite(member.id)
    member_scope = scope |> membership_scope(member, membership)

    assert {:ok, membership} =
             member_scope |> Membership.accept(membership, "  Téam   Member  ")

    assert membership.status == :active
    assert membership.display_name == "Téam Member"
    assert membership.slug == "team-member"

    assert {:ok, membership} = scope |> Membership.disable(membership)
    assert membership.status == :disabled
    assert {:ok, membership} = scope |> Membership.reinvite(membership)
    assert {:ok, membership} = member_scope |> Membership.accept(membership, nil)

    assert membership.status == :active
    assert membership.display_name == "Téam Member"
    assert membership.slug == "team-member"
  end

  test "declining an invitation preserves a declined membership", %{scope: scope} do
    scope = scope |> activate_owner()
    member = create_user("Member")
    {:ok, membership} = scope |> Membership.invite(member.id)
    member_scope = scope |> membership_scope(member, membership)

    assert {:ok, membership} = member_scope |> Membership.decline(membership)
    assert membership.status == :declined
    assert {:ok, membership} = scope |> Membership.reinvite(membership)
    assert membership.status == :invited
  end

  test "the owner cannot decline or disable their membership", %{scope: scope} do
    {:ok, membership} = scope |> Membership.get()

    assert {:error, _error} = scope |> Membership.decline(membership)
    assert {:ok, membership} = scope |> Membership.accept(membership, "Owner")
    assert {:error, _error} = scope |> Membership.disable(membership)
  end

  test "member slugs are unique within a space", %{scope: scope} do
    scope = scope |> activate_owner()
    first_user = create_user("First User")
    second_user = create_user("Second User")

    assert {:ok, first_membership} = scope |> Membership.invite(first_user.id)
    assert {:ok, second_membership} = scope |> Membership.invite(second_user.id)
    first_scope = scope |> membership_scope(first_user, first_membership)
    second_scope = scope |> membership_scope(second_user, second_membership)

    assert {:ok, _membership} =
             first_scope |> Membership.accept(first_membership, "Same Name")

    assert {:error, _error} =
             second_scope |> Membership.accept(second_membership, "Same Name")
  end

  test "the owner can set a member's privileges", %{scope: scope} do
    scope = scope |> activate_owner()
    member = create_user("Member")
    {:ok, membership} = scope |> Membership.invite(member.id)

    assert {:ok, membership} =
             scope
             |> Membership.set_privileges(membership, [
               :manage_members,
               :edit_pages,
               :manage_members
             ])

    assert membership.privileges == [:edit_pages, :manage_members]

    {:ok, owner_membership} = scope |> Membership.get()

    assert {:error, _error} =
             scope
             |> Membership.set_privileges(owner_membership, [:edit_pages])
  end

  test "privilege management can be delegated without granting a role", %{scope: scope} do
    scope = scope |> activate_owner()
    privilege_manager = create_user("Privilege Manager")
    member = create_user("Member")
    {:ok, manager_membership} = scope |> Membership.invite(privilege_manager.id)
    {:ok, membership} = scope |> Membership.invite(member.id)
    manager_scope = scope |> membership_scope(privilege_manager, manager_membership)

    assert {:ok, manager_membership} =
             manager_scope |> Membership.accept(manager_membership, "Privilege Manager")

    assert {:ok, manager_membership} =
             scope
             |> Membership.set_privileges(manager_membership, [:manage_privileges])

    manager_scope = %{manager_scope | membership: manager_membership}

    assert {:ok, membership} =
             manager_scope
             |> Membership.set_privileges(membership, [:edit_pages, :manage_space])

    assert membership.privileges == [:edit_pages, :manage_space]
  end

  test "ordinary members cannot change privileges", %{scope: scope} do
    scope = scope |> activate_owner()
    first_member = create_user("First Member")
    second_member = create_user("Second Member")
    {:ok, first_membership} = scope |> Membership.invite(first_member.id)
    {:ok, second_membership} = scope |> Membership.invite(second_member.id)
    member_scope = scope |> membership_scope(first_member, first_membership)

    {:ok, first_membership} =
      member_scope |> Membership.accept(first_membership, "First")

    member_scope = %{member_scope | membership: first_membership}

    assert {:error, _error} =
             member_scope
             |> Membership.set_privileges(second_membership, [:manage_privileges])
  end

  test "privilege managers cannot change their own privileges", %{scope: scope} do
    scope = scope |> activate_owner()
    manager = create_user("Privilege Manager")
    {:ok, membership} = scope |> Membership.invite(manager.id)
    manager_scope = scope |> membership_scope(manager, membership)
    {:ok, membership} = manager_scope |> Membership.accept(membership, "Manager")

    {:ok, membership} =
      scope |> Membership.set_privileges(membership, [:manage_privileges])

    manager_scope = %{manager_scope | membership: membership}

    assert {:error, _error} =
             manager_scope
             |> Membership.set_privileges(membership, [
               :edit_pages,
               :manage_privileges
             ])
  end

  test "memberships are isolated by space", %{scope: scope} do
    other_scope = %Scope{user: scope.user}
    other_space = Space.create!(%{name: "Other Space"}, scope: other_scope)
    other_scope = %{other_scope | space: other_space}

    assert {:ok, first_membership} = scope |> Membership.get()
    assert {:ok, second_membership} = other_scope |> Membership.get()

    refute first_membership.id == second_membership.id
    assert first_membership.space_id == scope.space.id
    assert second_membership.space_id == other_scope.space.id
  end

  test "membership visibility privileges expose pending and disabled memberships separately", %{
    scope: scope
  } do
    scope = scope |> activate_owner()
    viewer = create_user("Viewer")
    pending_user = create_user("Pending")
    disabled_user = create_user("Disabled")
    {:ok, viewer_membership} = scope |> Membership.invite(viewer.id)
    {:ok, _pending_membership} = scope |> Membership.invite(pending_user.id)
    {:ok, disabled_membership} = scope |> Membership.invite(disabled_user.id)
    viewer_scope = scope |> membership_scope(viewer, viewer_membership)
    disabled_scope = scope |> membership_scope(disabled_user, disabled_membership)

    {:ok, viewer_membership} =
      viewer_scope |> Membership.accept(viewer_membership, "Viewer")

    {:ok, disabled_membership} =
      disabled_scope |> Membership.accept(disabled_membership, "Disabled")

    {:ok, disabled_membership} = scope |> Membership.disable(disabled_membership)

    {:ok, viewer_membership} =
      scope
      |> Membership.set_privileges(viewer_membership, [:view_pending_memberships])

    viewer_scope = %{viewer_scope | membership: viewer_membership}

    assert [_pending_membership] = viewer_scope |> Membership.list!(:pending)

    assert [] = viewer_scope |> Membership.list!(:disabled)

    {:ok, viewer_membership} =
      scope
      |> Membership.set_privileges(viewer_membership, [
        :view_disabled_memberships,
        :view_pending_memberships
      ])

    viewer_scope = %{viewer_scope | membership: viewer_membership}

    assert [listed_membership] = viewer_scope |> Membership.list!(:disabled)
    assert listed_membership.id == disabled_membership.id
  end

  test "invalid lifecycle transitions are rejected", %{scope: scope} do
    {:ok, membership} = scope |> Membership.get()

    assert {:error, _error} = scope |> Membership.disable(membership)
    assert {:ok, membership} = scope |> Membership.accept(membership, "Member")
    assert {:error, _error} = scope |> Membership.decline(membership)
  end

  test "a first acceptance requires a usable display name", %{scope: scope} do
    {:ok, membership} = scope |> Membership.get()

    assert {:error, _error} = scope |> Membership.accept(membership, nil)
    assert {:error, _error} = scope |> Membership.accept(membership, "---")

    assert {:ok, reloaded} = Ash.get(Membership, membership.id, scope: scope)
    assert reloaded.status == :invited
  end

  defp activate_owner(scope) do
    {:ok, membership} = scope |> Membership.get()
    {:ok, membership} = scope |> Membership.accept(membership, scope.user.display_name)

    %{scope | membership: membership}
  end

  defp membership_scope(scope, user, membership) do
    %Scope{
      membership: membership,
      space: scope.space,
      user: user
    }
  end
end
