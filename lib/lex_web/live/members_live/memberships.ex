defmodule LexWeb.MembersLive.Memberships do
  use LexWeb, :live_view
  use LiveDelegate, path: [:memberships]

  require Logger

  alias Lex.Accounts.Membership
  alias Lex.Accounts.Membership.Access
  alias Lex.Accounts.Privilege
  alias LexWeb.Components.Avatar
  alias LexWeb.Router.Path

  def on_mount(_params, _session, socket) do
    socket
    |> delegate_assign(%{
      active: [],
      available_privileges: Access.available_privileges(),
      declined: [],
      disabled: [],
      pending: []
    })
    |> reload()
  end

  def reload(socket) do
    scope = socket.assigns.scope

    active = scope |> Membership.list!(:active)
    pending = scope |> list_or_empty(:pending)
    declined = scope |> list_or_empty(:declined)
    disabled = scope |> list_or_empty(:disabled)

    socket
    |> delegate_assign(:active, active)
    |> delegate_assign(:pending, pending)
    |> delegate_assign(:declined, declined)
    |> delegate_assign(:disabled, disabled)
  end

  @impl true
  def handle_event(
        "toggle_privilege",
        %{"membership_id" => membership_id, "privilege" => value},
        socket
      ) do
    scope = socket.assigns.scope

    with {:ok, privilege} <- Privilege.match(value),
         {:ok, membership} <- scope |> Membership.get(membership_id),
         privileges = toggle(membership.privileges, privilege),
         {:ok, _membership} <- scope |> Membership.set_privileges(membership, privileges) do
      socket = socket |> reload()

      {:noreply, socket}
    else
      error ->
        socket = socket |> operation_failed("Could not change privileges", error)

        {:noreply, socket}
    end
  end

  def handle_event("disable", %{"membership_id" => membership_id}, socket) do
    scope = socket.assigns.scope

    with {:ok, membership} <- scope |> Membership.get(membership_id),
         {:ok, _membership} <- scope |> Membership.disable(membership) do
      socket = socket |> reload()

      {:noreply, socket}
    else
      error ->
        socket = socket |> operation_failed("Could not disable member", error)

        {:noreply, socket}
    end
  end

  def handle_event("reinvite", %{"membership_id" => membership_id}, socket) do
    scope = socket.assigns.scope

    with {:ok, membership} <- scope |> Membership.get(membership_id),
         {:ok, _membership} <- scope |> Membership.reinvite(membership) do
      socket = socket |> reload()

      {:noreply, socket}
    else
      error ->
        socket = socket |> operation_failed("Could not reinvite member", error)

        {:noreply, socket}
    end
  end

  attr :memberships, :map, required: true
  attr :scope, :map, required: true

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl space-y-6">
      <div class="space-y-2" data-testid="memberships">
        <%= for memberships <- [
          @memberships.active,
          @memberships.pending,
          @memberships.declined,
          @memberships.disabled
        ] do %>
          <.membership
            :for={membership <- memberships}
            available_privileges={@memberships.available_privileges}
            membership={membership}
            scope={@scope}
          />
        <% end %>
      </div>
    </div>
    """
  end

  defp membership(assigns) do
    ~H"""
    <article
      class={[
        "py-4",
        "px-4 py-2 rounded",
        "bg-card",
        @membership.status != :active && "opacity-80"
      ]}
      data-testid="membership"
    >
      <div>
        <div>
          <div class="flex flex-wrap items-center gap-2">
            <h2 class="font-semibold">
              <.link
                :if={@membership.status == :active}
                navigate={Path.to(@scope, @membership)}
                class="clickable"
              >
                <Avatar.render user={@membership.user} />
                {membership_name(@membership)}
              </.link>

              <span :if={@membership.status != :active} class="opacity-50">
                <Avatar.render user={@membership.user} />
                {membership_name(@membership)}
              </span>
            </h2>

            <div class="ml-auto">
              <span
                :if={@membership.status == :active && @membership.user_id != @scope.space.owner_id}
                class="badge badge-sm badge-success"
              >
                Active
              </span>
              <span :if={@membership.status == :declined} class="badge badge-sm">
                Declined
              </span>
              <span
                :if={@membership.status == :disabled}
                class="badge badge-sm badge-error"
              >
                Disabled
              </span>
              <span
                :if={@membership.status == :invited}
                class="badge badge-sm badge-warning"
              >
                Pending
              </span>
              <span
                :if={@membership.user_id == @scope.space.owner_id}
                class="badge badge-sm badge-info"
              >
                Owner
              </span>
            </div>
          </div>
          <p
            :if={
              @membership.display_name != nil &&
                @membership.display_name != @membership.user.display_name
            }
            class="text-sm text-base-content/50"
          >
            {@membership.user.display_name}
          </p>
        </div>

        <div :if={
          can?(@scope, :manage_members) &&
            @membership.user_id != @scope.space.owner_id &&
            @membership.user_id != @scope.user.id
        }>
          <button
            :if={@membership.status == :active}
            class="btn btn-sm btn-ghost hover:btn-error"
            data-testid="disable-member"
            phx-click={delegate_event("disable")}
            phx-value-membership_id={@membership.id}
            type="button"
          >
            Disable
          </button>
          <button
            :if={@membership.status in [:declined, :disabled]}
            class="btn btn-sm btn-ghost hover:btn-info"
            data-testid="reinvite-member"
            phx-click={delegate_event("reinvite")}
            phx-value-membership_id={@membership.id}
            type="button"
          >
            Reinvite
          </button>
        </div>
      </div>

      <div
        :if={
          can?(@scope, :manage_privileges) &&
            @membership.user_id != @scope.space.owner_id &&
            @membership.user_id != @scope.user.id
        }
        class="mt-4 flex flex-wrap gap-2 border-t border-base-content/10 pt-3"
      >
        <button
          :for={privilege <- @available_privileges}
          aria-pressed={privilege in @membership.privileges}
          class={[
            "btn btn-sm",
            privilege in @membership.privileges && "btn-info",
            privilege not in @membership.privileges && "btn-soft opacity-60 hover:btn-info transition"
          ]}
          data-testid="membership-privilege"
          phx-click={delegate_event("toggle_privilege")}
          phx-value-membership_id={@membership.id}
          phx-value-privilege={privilege}
          title={Privilege.description(privilege)}
          type="button"
        >
          {Privilege.label(privilege)}
        </button>
      </div>
    </article>
    """
  end

  defp list_or_empty(scope, selection) do
    scope
    |> Membership.list(selection)
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

  defp operation_failed(socket, message, error) do
    Logger.warning("#{message}: #{inspect(error)}")

    socket |> put_flash(:error, message)
  end
end
