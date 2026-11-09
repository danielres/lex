defmodule LexWeb.CollaborationSocketTest do
  use LexWeb.ConnCase

  require Phoenix.ChannelTest

  alias Lex.Accounts.Membership
  alias Lex.Accounts.Space

  @endpoint LexWeb.Endpoint

  test "builds the Ash scope from the authenticated session and requested space", %{conn: conn} do
    current_user = create_user()
    actor_scope = %Lex.Scope{user: current_user}
    space = Space.create!(%{name: "Test Space"}, scope: actor_scope)
    scope = %{actor_scope | space: space}
    {:ok, membership} = scope |> Membership.get()
    {:ok, membership} = scope |> Membership.accept(membership, "Test Member")
    conn = log_in_user(conn, current_user)

    assert {:ok, socket} =
             Phoenix.ChannelTest.connect(
               LexWeb.CollaborationSocket,
               %{"space_id" => space.id},
               connect_info: %{session: get_session(conn)}
             )

    assert socket.assigns.scope.user.id == current_user.id
    assert socket.assigns.scope.membership.id == membership.id
    assert socket.assigns.scope.space.id == space.id
    assert socket.assigns.can_edit_pages?
  end

  test "connects active members without editing privileges as read-only", %{conn: conn} do
    owner_scope = create_scope()
    member = create_user("Reader")
    {:ok, membership} = owner_scope |> Membership.invite(member.id)
    member_scope = %{owner_scope | membership: membership, user: member}
    {:ok, membership} = member_scope |> Membership.accept(membership, "Reader")
    {:ok, membership} = owner_scope |> Membership.set_privileges(membership, [])
    conn = conn |> log_in_user(member)

    assert {:ok, socket} =
             Phoenix.ChannelTest.connect(
               LexWeb.CollaborationSocket,
               %{"space_id" => owner_scope.space.id},
               connect_info: %{session: get_session(conn)}
             )

    assert socket.assigns.scope.membership.id == membership.id
    refute socket.assigns.can_edit_pages?
  end

  test "rejects an invited member", %{conn: conn} do
    current_user = create_user()
    actor_scope = %Lex.Scope{user: current_user}
    space = Space.create!(%{name: "Test Space"}, scope: actor_scope)
    conn = log_in_user(conn, current_user)

    assert :error =
             Phoenix.ChannelTest.connect(
               LexWeb.CollaborationSocket,
               %{"space_id" => space.id},
               connect_info: %{session: get_session(conn)}
             )
  end

  test "rejects an unauthenticated session" do
    assert :error =
             Phoenix.ChannelTest.connect(
               LexWeb.CollaborationSocket,
               %{"space_id" => Ecto.UUID.generate()},
               connect_info: %{session: %{}}
             )
  end

  test "rejects a missing session" do
    assert :error =
             Phoenix.ChannelTest.connect(
               LexWeb.CollaborationSocket,
               %{"space_id" => Ecto.UUID.generate()},
               connect_info: %{session: nil}
             )
  end
end
