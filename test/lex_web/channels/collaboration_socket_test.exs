defmodule LexWeb.CollaborationSocketTest do
  use LexWeb.ConnCase

  require Phoenix.ChannelTest

  alias Lex.Accounts.Space

  @endpoint LexWeb.Endpoint

  test "builds the Ash scope from the authenticated session and requested space", %{conn: conn} do
    current_user = create_user()
    actor_scope = %Lex.Scope{current_user: current_user}
    space = Space.create!(%{name: "Test Space"}, scope: actor_scope)
    conn = log_in_user(conn, current_user)

    assert {:ok, socket} =
             Phoenix.ChannelTest.connect(
               LexWeb.CollaborationSocket,
               %{"space_id" => space.id},
               connect_info: %{session: get_session(conn)}
             )

    assert socket.assigns.scope.current_user.id == current_user.id
    assert socket.assigns.scope.space_id == space.id
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
