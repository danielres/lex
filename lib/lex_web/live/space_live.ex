defmodule LexWeb.SpaceLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias LexWeb.Router.Path
  alias LexWeb.UI

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
      scope={@scope}
      socket={@socket}
      ui={@ui}
    >
      <:page_head>
        <Layouts.page_head>
          <:crumb>
            <.link navigate={Path.spaces()} class="clickable">Spaces</.link>
          </:crumb>
          <:title>{@scope.space.name}</:title>
        </Layouts.page_head>
      </:page_head>
    </Layouts.app>
    """
  end
end
