defmodule LexWeb.MembersLiveTest do
  use LexWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Lex.Accounts

  setup :authenticate

  setup %{current_user: current_user} do
    {:ok, scope: create_scope("Test Space", current_user)}
  end

  test "active members can view the member directory", %{conn: conn, scope: scope} do
    member = create_user("Directory Member")
    member_scope = scope |> add_member(member, "Member Profile")
    invited_user = create_user("Invited Person")
    {:ok, _membership} = scope |> Accounts.invite_membership(invited_user)
    conn = conn |> recycle() |> log_in_user(member)

    {:ok, view, _html} = live(conn, ~p"/test-space/members")

    assert has_element?(view, "[data-testid='membership']", "Member Profile")
    assert has_element?(view, "[data-testid='membership']", scope.membership.display_name)
    refute has_element?(view, "[data-testid='membership']", "Invited Person")
    refute has_element?(view, "[data-testid='membership-privilege']")
    refute has_element?(view, "[data-testid='disable-member']")
    refute has_element?(view, "[data-testid='invite-members']")
    assert member_scope.membership.status == :active
  end

  test "the owner can invite an existing user", %{conn: conn, scope: scope} do
    user = create_user("New Member")

    {:ok, view, _html} = live(conn, ~p"/test-space/members")

    view
    |> element("[data-testid='invite-member'][phx-value-user_id='#{user.id}']")
    |> render_click()

    assert has_element?(view, "[data-testid='membership']", "New Member")
    refute has_element?(view, "[data-testid='invite-member'][phx-value-user_id='#{user.id}']")

    invited_scope = %{scope | membership: nil, user: user}
    assert {:ok, membership} = invited_scope |> Accounts.get_membership()
    assert membership.status == :invited
  end

  test "the owner can change privileges and membership lifecycle", %{conn: conn, scope: scope} do
    member = create_user("Managed Member")
    member_scope = scope |> add_member(member, "Managed Profile")
    membership = member_scope.membership

    {:ok, view, _html} = live(conn, ~p"/test-space/members")

    view
    |> element(
      "[data-testid='membership-privilege'][phx-value-membership_id='#{membership.id}'][phx-value-privilege='edit_pages']"
    )
    |> render_click()

    assert {:ok, membership} = scope |> Accounts.get_membership(membership.id)
    assert membership.privileges == []

    view
    |> element("[data-testid='disable-member'][phx-value-membership_id='#{membership.id}']")
    |> render_click()

    assert {:ok, membership} = scope |> Accounts.get_membership(membership.id)
    assert membership.status == :disabled

    view
    |> element("[data-testid='reinvite-member'][phx-value-membership_id='#{membership.id}']")
    |> render_click()

    assert {:ok, membership} = scope |> Accounts.get_membership(membership.id)
    assert membership.status == :invited
  end

  defp add_member(scope, user, display_name) do
    {:ok, membership} = scope |> Accounts.invite_membership(user)
    member_scope = %{scope | membership: membership, user: user}
    {:ok, membership} = member_scope |> Accounts.accept_membership(membership, display_name)

    %{member_scope | membership: membership}
  end
end
