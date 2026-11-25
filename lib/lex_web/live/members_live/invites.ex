defmodule LexWeb.MembersLive.Invites do
  use LexWeb, :live_view
  use LiveDelegate, path: [:invites]

  require Logger

  alias Lex.Accounts.Membership
  alias LexWeb.MembersLive.Memberships

  def on_mount(_params, _session, socket) do
    socket
    |> delegate_assign(%{open?: false, users: []})
    |> reload()
  end

  def reload(socket) do
    scope = socket.assigns.scope

    users =
      if can?(scope, :manage_members) do
        scope |> Membership.list_invitable_users!()
      else
        []
      end

    socket |> delegate_assign(:users, users)
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    open? = !socket.assigns.invites.open?
    socket = socket |> delegate_assign(:open?, open?)

    {:noreply, socket}
  end

  def handle_event("invite", %{"user_id" => user_id}, socket) do
    scope = socket.assigns.scope

    with {:ok, _membership} <- scope |> Membership.invite(user_id) do
      socket =
        socket
        |> Memberships.reload()
        |> reload()

      {:noreply, socket}
    else
      error ->
        socket = socket |> operation_failed("Could not invite member", error)

        {:noreply, socket}
    end
  end

  attr :invites, :map, required: true

  @impl true
  def render(assigns) do
    ~H"""
    <div data-testid="invite-members">
      <p :if={@invites.users == []} class="text-sm text-base-content/60">
        There are no users available to invite.
      </p>

      <div :if={@invites.users != []} class="divide-y divide-base-content/20">
        <div
          :for={user <- @invites.users}
          class="flex items-center justify-between gap-3 py-2"
          data-testid="invitable-user"
        >
          <span class="font-medium">{user.display_name}</span>
          <button
            class="btn btn-sm btn-info"
            data-testid="invite-member"
            phx-click={delegate_event("invite")}
            phx-value-user_id={user.id}
            type="button"
          >
            Invite
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :invites, :map, required: true
  attr :scope, :map, required: true

  def button_toggle(assigns) do
    ~H"""
    <button
      :if={can?(@scope, :manage_members)}
      aria-label="Add members"
      class={[
        "btn btn-xs btn-circle",
        @invites.open? && "btn-info"
      ]}
      data-testid="add-members-button"
      title="Add members"
      phx-click={delegate_event("toggle")}
    >
      <.icon :if={!@invites.open?} name="hero-user-plus-micro" />
      <.icon :if={@invites.open?} name="hero-x-mark-micro" />
    </button>
    """
  end

  defp operation_failed(socket, message, error) do
    Logger.warning("#{message}: #{inspect(error)}")

    socket |> put_flash(:error, message)
  end
end
