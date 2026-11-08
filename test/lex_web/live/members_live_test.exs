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
    assert has_element?(view, "[data-testid='membership']", scope.current_membership.display_name)
    refute has_element?(view, "[data-testid='membership']", "Invited Person")
    refute has_element?(view, "[data-testid='membership-privilege']")
    refute has_element?(view, "[data-testid='disable-member']")
    assert member_scope.current_membership.status == :active
  end

  test "the owner can change privileges and membership lifecycle", %{conn: conn, scope: scope} do
    member = create_user("Managed Member")
    member_scope = scope |> add_member(member, "Managed Profile")
    membership = member_scope.current_membership

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
    member_scope = %{scope | current_membership: membership, current_user: user}
    {:ok, membership} = member_scope |> Accounts.accept_membership(membership, display_name)

    %{member_scope | current_membership: membership}
  end
end
