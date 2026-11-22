defmodule LexWeb.MemberLiveTest do
  use LexWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Lex.Accounts.Membership

  setup :authenticate

  setup %{current_user: current_user} do
    {:ok, scope: create_scope("Test Space", current_user)}
  end

  test "active members can view another active member's profile", %{conn: conn, scope: scope} do
    viewer = create_user("Profile Viewer")
    viewer_scope = scope |> add_member(viewer, "Profile Viewer")
    profile = create_user("Profile Member")
    profile_scope = scope |> add_member(profile, "Profile Member")
    conn = conn |> recycle() |> log_in_user(viewer)

    {:ok, view, _html} =
      live(conn, ~p"/test-space/members/#{profile_scope.membership.slug}")

    assert render(view) =~ "Profile Member"
    assert viewer_scope.membership.status == :active
  end

  test "active members cannot view a disabled member's profile", %{conn: conn, scope: scope} do
    viewer = create_user("Profile Viewer")
    _viewer_scope = scope |> add_member(viewer, "Profile Viewer")
    profile = create_user("Disabled Profile")
    profile_scope = scope |> add_member(profile, "Disabled Profile")
    {:ok, _membership} = scope |> Membership.disable(profile_scope.membership)
    conn = conn |> recycle() |> log_in_user(viewer)

    assert {:error, {:live_redirect, %{to: "/test-space"}}} =
             live(conn, ~p"/test-space/members/#{profile_scope.membership.slug}")
  end

  defp add_member(scope, user, display_name) do
    {:ok, membership} = scope |> Membership.invite(user.id)
    member_scope = %{scope | membership: membership, user: user}
    {:ok, membership} = member_scope |> Membership.accept(membership, display_name)

    %{member_scope | membership: membership}
  end
end
