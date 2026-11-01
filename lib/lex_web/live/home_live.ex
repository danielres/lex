defmodule LexWeb.HomeLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias LexWeb.UI

  delegate(:ui, UI)

  def mount(params, session, socket) do
    socket = delegate_mount(socket, params, session)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      active="dashboard"
      flash={@flash}
      socket={@socket}
      ui={@ui}
      user={@collaborator}
    >
      Hello
    </Layouts.app>
    """
  end
end
