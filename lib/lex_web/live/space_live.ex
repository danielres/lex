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
      scope={@scope}
      socket={@socket}
      space={@space}
      ui={@ui}
    >
      <div class="space-y-2">
        <div>
          <.link navigate={~p"/"} class="opacity-80 hover:opacity-100 transition">
            <.icon name="hero-arrow-left-micro" class="font-semibold size-3" />
            <span class="text-xs">All spaces</span>
          </.link>
        </div>

        <h1 class={[
          "text-2xl",
          "border-b-2 border-base-content/20"
        ]}>
          {@space.name}
        </h1>
      </div>
    </Layouts.app>
    """
  end
end
