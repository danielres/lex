defmodule LexWeb.MembershipOnboardingLiveTest do
  use LexWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Lex.Accounts.Membership
  alias Lex.Accounts.Space

  setup :authenticate

  test "redirects an invited owner to onboarding and activates the membership", %{
    conn: conn,
    current_user: current_user
  } do
    scope = %Lex.Scope{user: current_user}
    space = Space.create!(%{name: "Test Space"}, scope: scope)
    scope = %{scope | space: space}

    assert {:error, {:redirect, %{to: "/test-space/join"}}} =
             live(conn, ~p"/test-space")

    assert {:error, {:redirect, %{to: "/test-space/join"}}} =
             live(conn, ~p"/test-space/wiki")

    {:ok, view, _html} = live(conn, ~p"/test-space/join")

    assert has_element?(
             view,
             "[data-testid='membership-onboarding-form'] input[value='#{current_user.display_name}']"
           )

    refute has_element?(view, "[data-testid='decline-membership']")

    view
    |> form("[data-testid='membership-onboarding-form']",
      membership: %{display_name: "Space Identity"}
    )
    |> render_submit()

    assert_redirect(view, ~p"/test-space")
    assert {:ok, membership} = scope |> Membership.get()
    assert membership.status == :active
    assert membership.display_name == "Space Identity"
  end

  test "redirects an active member away from onboarding", %{
    conn: conn,
    current_user: current_user
  } do
    scope = create_scope("Test Space", current_user)

    assert {:error, {:redirect, %{to: "/test-space"}}} =
             live(conn, ~p"/test-space/join")

    assert scope.membership.status == :active
  end

  test "lets an invited member decline", %{conn: conn} do
    owner = create_user("Owner")
    owner_scope = create_scope("Test Space", owner)
    invited_user = create_user("Invited User")
    {:ok, invitation} = owner_scope |> Membership.invite(invited_user.id)
    conn = conn |> log_in_user(invited_user)

    {:ok, view, _html} = live(conn, ~p"/test-space/join")

    view
    |> element("[data-testid='decline-membership']")
    |> render_click()

    assert_redirect(view, ~p"/")

    invited_scope = %Lex.Scope{space: owner_scope.space, user: invited_user}
    assert {:ok, membership} = invited_scope |> Membership.get()
    assert membership.id == invitation.id
    assert membership.status == :declined
  end
end
