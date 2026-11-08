defmodule LexWeb.MembersLive do
  use LexWeb, :live_view
  use LiveDelegate

  require Logger

  alias Lex.Accounts
  alias Lex.Accounts.Privilege
  alias LexWeb.Space
  alias LexWeb.UI

  delegate(:space, Space)
  delegate(:ui, UI)

  @impl true
  def mount(params, session, socket) do
    socket = socket |> delegate_mount(params, session)
    scope = socket.assigns.scope
    space = socket.assigns.space

    available_privileges = Privilege.values()
    effective_privileges = scope |> Accounts.effective_privileges(space)

    socket =
      socket
      |> assign(:available_privileges, available_privileges)
      |> assign(:effective_privileges, effective_privileges)
      |> reload_memberships()

    {:ok, socket}
  end

  @impl true
  def handle_event(
        "toggle_privilege",
        %{"membership_id" => membership_id, "privilege" => value},
        socket
      ) do
    scope = socket.assigns.scope

    with {:ok, privilege} <- Privilege.match(value),
         {:ok, membership} <- scope |> Accounts.get_membership(membership_id),
         privileges = toggle(membership.privileges, privilege),
         {:ok, _membership} <-
           scope |> Accounts.set_membership_privileges(membership, privileges) do
      socket = socket |> reload_memberships()

      {:noreply, socket}
    else
      error ->
        socket = socket |> operation_failed("Could not change privileges", error)

        {:noreply, socket}
    end
  end

  def handle_event("disable", %{"membership_id" => membership_id}, socket) do
    scope = socket.assigns.scope

    with {:ok, membership} <- scope |> Accounts.get_membership(membership_id),
         {:ok, _membership} <- scope |> Accounts.disable_membership(membership) do
      socket = socket |> reload_memberships()

      {:noreply, socket}
    else
      error ->
        socket = socket |> operation_failed("Could not disable member", error)

        {:noreply, socket}
    end
  end

  def handle_event("reinvite", %{"membership_id" => membership_id}, socket) do
    scope = socket.assigns.scope

    with {:ok, membership} <- scope |> Accounts.get_membership(membership_id),
         {:ok, _membership} <- scope |> Accounts.reinvite_membership(membership) do
      socket = socket |> reload_memberships()

      {:noreply, socket}
    else
      error ->
        socket = socket |> operation_failed("Could not reinvite member", error)

        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      active="members"
      flash={@flash}
      scope={@scope}
      socket={@socket}
      space={@space}
      ui={@ui}
    >
      <div class="mx-auto max-w-3xl space-y-6">
        <div>
          <h1 class="text-2xl font-semibold">Members</h1>
          <p class="text-base-content/60">
            Memberships for {@space.name}.
          </p>
        </div>

        <div class="grid gap-3" data-testid="memberships">
          <%= for memberships <- [
            @active_memberships,
            @pending_memberships,
            @declined_memberships,
            @disabled_memberships
          ] do %>
            <article
              :for={membership <- memberships}
              class="rounded-box border border-base-content/15 bg-base-200 p-4"
              data-testid="membership"
            >
              <div class="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <div class="flex flex-wrap items-center gap-2">
                    <h2 class="font-semibold">{membership_name(membership)}</h2>
                    <span class={status_class(membership.status)}>
                      {status_label(membership.status)}
                    </span>
                    <span
                      :if={membership.user_id == @space.owner_id}
                      class="badge badge-sm badge-info"
                    >
                      Owner
                    </span>
                  </div>
                  <p
                    :if={
                      membership.display_name != nil &&
                        membership.display_name != membership.user.display_name
                    }
                    class="text-sm text-base-content/50"
                  >
                    {membership.user.display_name}
                  </p>
                </div>

                <div :if={
                  :manage_members in @effective_privileges &&
                    membership.user_id != @space.owner_id &&
                    membership.user_id != @scope.current_user.id
                }>
                  <button
                    :if={membership.status == :active}
                    class="btn btn-sm btn-ghost hover:btn-error"
                    data-testid="disable-member"
                    phx-click="disable"
                    phx-value-membership_id={membership.id}
                    type="button"
                  >
                    Disable
                  </button>
                  <button
                    :if={membership.status in [:declined, :disabled]}
                    class="btn btn-sm btn-ghost hover:btn-info"
                    data-testid="reinvite-member"
                    phx-click="reinvite"
                    phx-value-membership_id={membership.id}
                    type="button"
                  >
                    Reinvite
                  </button>
                </div>
              </div>

              <div
                :if={
                  :manage_privileges in @effective_privileges &&
                    membership.user_id != @space.owner_id &&
                    membership.user_id != @scope.current_user.id
                }
                class="mt-4 flex flex-wrap gap-2 border-t border-base-content/10 pt-3"
              >
                <button
                  :for={privilege <- @available_privileges}
                  aria-pressed={privilege in membership.privileges}
                  class={[
                    "btn btn-sm",
                    privilege in membership.privileges && "btn-info",
                    privilege not in membership.privileges && "btn-ghost"
                  ]}
                  data-testid="membership-privilege"
                  phx-click="toggle_privilege"
                  phx-value-membership_id={membership.id}
                  phx-value-privilege={privilege}
                  title={Privilege.description(privilege)}
                  type="button"
                >
                  {Privilege.label(privilege)}
                </button>
              </div>
            </article>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp reload_memberships(socket) do
    scope = socket.assigns.scope
    space = socket.assigns.space

    active_memberships = space |> Accounts.list_memberships!(scope, :active)
    pending_memberships = space |> list_memberships_or_empty(scope, :pending)
    declined_memberships = space |> list_memberships_or_empty(scope, :declined)
    disabled_memberships = space |> list_memberships_or_empty(scope, :disabled)

    socket
    |> assign(:active_memberships, active_memberships)
    |> assign(:pending_memberships, pending_memberships)
    |> assign(:declined_memberships, declined_memberships)
    |> assign(:disabled_memberships, disabled_memberships)
  end

  defp list_memberships_or_empty(space, scope, selection) do
    space
    |> Accounts.list_memberships(scope, selection)
    |> case do
      {:ok, memberships} -> memberships
      {:error, %Ash.Error.Forbidden{}} -> []
      {:error, error} -> raise error
    end
  end

  defp toggle(privileges, privilege) do
    if privilege in privileges do
      List.delete(privileges, privilege)
    else
      [privilege | privileges]
    end
  end

  defp membership_name(%{display_name: nil, user: user}), do: user.display_name
  defp membership_name(membership), do: membership.display_name

  defp status_class(:active), do: "badge badge-sm badge-success"
  defp status_class(:declined), do: "badge badge-sm"
  defp status_class(:disabled), do: "badge badge-sm badge-error"
  defp status_class(:invited), do: "badge badge-sm badge-warning"

  defp status_label(:active), do: "Active"
  defp status_label(:declined), do: "Declined"
  defp status_label(:disabled), do: "Disabled"
  defp status_label(:invited), do: "Pending"

  defp operation_failed(socket, message, error) do
    Logger.warning("#{message}: #{inspect(error)}")

    socket |> put_flash(:error, message)
  end
end
