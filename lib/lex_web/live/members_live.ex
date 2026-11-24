defmodule LexWeb.MembersLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias LexWeb.MembersLive.Invites
  alias LexWeb.MembersLive.Memberships
  alias LexWeb.UI

  delegate(:invites, Invites, info: false)
  delegate(:memberships, Memberships, info: false)
  delegate(:ui, UI)

  @impl true
  def mount(params, session, socket) do
    socket = socket |> delegate_mount(params, session)
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      active="members"
      flash={@flash}
      scope={@scope}
      socket={@socket}
      ui={@ui}
    >
      <Layouts.page_head dialog?={@invites.open?}>
        <:title>Members</:title>

        <:dialog :if={@invites.open?}>
          <Invites.render invites={@invites} />
        </:dialog>

        <:actions>
          <Invites.button_toggle invites={@invites} scope={@scope} />
        </:actions>
      </Layouts.page_head>

      <Memberships.render memberships={@memberships} scope={@scope} />
    </Layouts.app>
    """
  end
end
