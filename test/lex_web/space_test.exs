defmodule LexWeb.SpaceTest do
  use Lex.DataCase

  alias Lex.Accounts.Space

  test "assigns the space resolved from the route slug" do
    current_user = create_user()
    scope = %Lex.Scope{current_user: current_user}
    space = Space.create!(%{name: "Test Space"}, scope: scope)
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, scope: scope}}

    socket = LexWeb.Space.on_mount(%{"space_slug" => space.slug}, %{}, socket)

    assert socket.assigns.scope.current_user.id == current_user.id
    assert socket.assigns.scope.space_id == space.id
    assert socket.assigns.space.id == space.id
    assert socket.assigns.space.name == "Test Space"
    assert socket.assigns.space.slug == "test-space"
  end
end
