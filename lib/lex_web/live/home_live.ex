defmodule LexWeb.HomeLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias LexWeb.Presences
  alias LexWeb.UI

  delegate(:presences, Presences, info: [:group])
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
      presences={@presences}
      ui={@ui}
      user={@collaborator}
    >
      Hello
    </Layouts.app>
    """
  end
end
