defmodule LexWeb.MembershipOnboardingLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias Lex.Accounts
  alias LexWeb.Space

  delegate(:space, Space)

  @impl true
  def mount(params, session, socket) do
    socket = socket |> delegate_mount(params, session)

    if socket.redirected do
      {:ok, socket}
    else
      scope = socket.assigns.scope

      form =
        scope.membership
        |> AshPhoenix.Form.for_update(:accept,
          as: "membership",
          params: %{"display_name" => scope.user.display_name},
          scope: scope
        )
        |> to_form()

      socket = socket |> assign(form: form)

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("validate", %{"membership" => params}, socket) do
    form = socket.assigns.form |> AshPhoenix.Form.validate(params)
    socket = socket |> assign(form: form)

    {:noreply, socket}
  end

  def handle_event("accept", %{"membership" => params}, socket) do
    socket.assigns.form
    |> AshPhoenix.Form.submit(params: params)
    |> case do
      {:ok, _membership} ->
        socket = socket |> push_navigate(to: ~p"/#{socket.assigns.scope.space.slug}")

        {:noreply, socket}

      {:error, form} ->
        socket = socket |> assign(form: form)

        {:noreply, socket}
    end
  end

  def handle_event("decline", _params, socket) do
    scope = socket.assigns.scope

    scope
    |> Accounts.decline_membership(scope.membership)
    |> case do
      {:ok, _membership} ->
        socket = socket |> push_navigate(to: ~p"/")

        {:noreply, socket}

      {:error, error} ->
        raise error
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-svh items-center justify-center p-4">
      <div class="w-full max-w-md space-y-6 rounded-box bg-base-200 p-6 shadow-sm">
        <div class="space-y-1">
          <p class="text-sm text-base-content/60">Join space</p>
          <h1 class="text-2xl font-semibold">{@scope.space.name}</h1>
          <p class="text-sm text-base-content/70">
            Choose the name other members will see in this space. It cannot be changed later.
          </p>
        </div>

        <.form
          for={@form}
          class="space-y-4"
          data-testid="membership-onboarding-form"
          phx-change="validate"
          phx-submit="accept"
        >
          <.input
            autocomplete="off"
            field={@form[:display_name]}
            label="Display name"
          />

          <div class="flex justify-between gap-3">
            <button
              :if={@scope.space.owner_id != @scope.user.id}
              class="btn btn-ghost"
              data-testid="decline-membership"
              phx-click="decline"
              type="button"
            >
              Decline
            </button>

            <button class="btn btn-info ml-auto" type="submit">Join</button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
