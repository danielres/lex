defmodule LexWeb.SpaceTest do
  use Lex.DataCase

  test "assigns the space resolved from the route slug" do
    current_user = create_user()
    scope = create_scope("Test Space", current_user)
    space = scope.space

    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, live_action: nil, scope: %{scope | membership: nil}}
    }

    socket = LexWeb.Space.on_mount(%{"space_slug" => space.slug}, %{}, socket)

    assert socket.assigns.scope.user.id == current_user.id
    assert socket.assigns.scope.membership.id == scope.membership.id
    assert socket.assigns.scope.space.id == space.id
    refute Map.has_key?(socket.assigns, :space)
  end
end
