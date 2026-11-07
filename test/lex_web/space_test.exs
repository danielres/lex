defmodule LexWeb.SpaceTest do
  use Lex.DataCase

  alias Lex.Accounts.Space

  test "assigns the space resolved from the route slug" do
    current_user = create_user()
    scope = create_scope("Test Space", current_user)
    space = Ash.get!(Space, scope.space_id, scope: scope)

    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, live_action: nil, scope: %{scope | current_membership: nil}}
    }

    socket = LexWeb.Space.on_mount(%{"space_slug" => space.slug}, %{}, socket)

    assert socket.assigns.scope.current_user.id == current_user.id
    assert socket.assigns.scope.current_membership.id == scope.current_membership.id
    assert socket.assigns.scope.space_id == space.id
    assert socket.assigns.space.id == space.id
    assert socket.assigns.space.name == "Test Space"
    assert socket.assigns.space.slug == "test-space"
  end
end
