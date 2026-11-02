defmodule LexWeb.SpaceTest do
  use Lex.DataCase

  alias Lex.Accounts.Space

  test "assigns the space resolved from the route slug" do
    space = Space.create!(%{name: "Test Space"})
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}

    socket = LexWeb.Space.on_mount(%{"space_slug" => space.slug}, %{}, socket)

    assert socket.assigns.space.id == space.id
    assert socket.assigns.space.name == "Test Space"
    assert socket.assigns.space.slug == "test-space"
  end
end
