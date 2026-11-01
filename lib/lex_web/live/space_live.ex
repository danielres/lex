defmodule LexWeb.SpaceLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias LexWeb.Space
  alias LexWeb.UI

  delegate(:space, Space)
  delegate(:ui, UI)

  def mount(params, session, socket) do
    socket = delegate_mount(socket, params, session)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      active="space"
      flash={@flash}
      socket={@socket}
      space={@space}
      ui={@ui}
      user={@collaborator}
    >
      Space "{@space.slug}"
    </Layouts.app>
    """
  end
end
