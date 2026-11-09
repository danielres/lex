defmodule LexWeb.HomeLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias Lex.Accounts.Membership
  alias Lex.Accounts.Space
  alias LexWeb.UI

  delegate(:ui, UI)

  @impl true
  def mount(params, session, socket) do
    socket = socket |> delegate_mount(params, session)
    scope = socket.assigns.scope

    space_form = scope |> space_form()
    memberships = scope |> Membership.list!()

    socket =
      socket
      |> assign(:creating_space?, false)
      |> assign(:memberships, memberships)
      |> assign(:space_form, space_form)

    {:ok, socket}
  end

  @impl true
  def handle_event("show_space_form", _params, socket) do
    socket = socket |> assign(creating_space?: true)

    {:noreply, socket}
  end

  def handle_event("cancel_space_creation", _params, socket) do
    scope = socket.assigns.scope
    space_form = scope |> space_form()

    socket =
      socket
      |> assign(:creating_space?, false)
      |> assign(:space_form, space_form)

    {:noreply, socket}
  end

  def handle_event("validate_space", %{"space" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.space_form, params)

    socket = socket |> assign(space_form: form)

    {:noreply, socket}
  end

  def handle_event("create_space", %{"space" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.space_form, params: params) do
      {:ok, space} ->
        socket =
          socket
          |> push_navigate(to: ~p"/#{space.slug}/join")

        {:noreply, socket}

      {:error, form} ->
        socket = socket |> assign(space_form: form)

        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={[
      "min-h-svh",
      "flex items-center justify-center"
    ]}>
      <div class="w-full max-w-md">
        <.list_spaces
          :if={!@creating_space?}
          memberships={@memberships}
        />

        <.creation_form
          :if={@creating_space?}
          space_form={@space_form}
        />
      </div>
    </div>
    """
  end

  defp creation_form(assigns) do
    ~H"""
    <.form
      for={@space_form}
      id="space-creation-form"
      class="space-y-3"
      data-testid="space-creation-form"
      phx-change="validate_space"
      phx-submit="create_space"
    >
      <.input
        autocomplete="off"
        field={@space_form[:name]}
        placeholder="Name"
        phx-hook="CapitalizeFirstLetter"
      />
      <.input field={@space_form[:description]} placeholder="Description" type="textarea" />

      <div class="flex justify-between">
        <button
          class="btn btn-ghost hover:btn-neutral"
          data-testid="cancel-space-creation"
          phx-click="cancel_space_creation"
          type="button"
        >
          Cancel
        </button>
        <button
          class="btn btn-info"
          type="submit"
        >
          <span>Create space</span>
        </button>
      </div>
    </.form>
    """
  end

  defp list_spaces(assigns) do
    grid_item_class = [
      "reactive",
      "p-4",
      "block",
      "aspect-square",
      "bg-base-100 rounded"
    ]

    assigns = assigns |> assign(grid_item_class: grid_item_class)

    ~H"""
    <%  %>
    <div>
      <h1 class="text-xl font-semibold border-b border-base-content/20 pb-2 mb-4">
        Your spaces
      </h1>

      <div class="autogrid gap-4 [--autogrid-min:8rem]">
        <.link
          :for={membership <- @memberships}
          navigate={~p"/#{membership.space.slug}"}
          data-testid="space"
          class={[
            @grid_item_class,
            "font-semibold",
            "leading-tight"
          ]}
        >
          <span>{membership.space.name}</span>
          <span
            :if={membership.status == :invited}
            class="mt-2 block text-xs font-normal text-base-content/60"
          >
            Invitation
          </span>
        </.link>

        <button
          type="button"
          phx-click="show_space_form"
          data-testid="show-space-form"
          class={[
            @grid_item_class,
            "hover:bg-info",
            "cursor-pointer"
          ]}
        >
          <.icon name="hero-plus-micro" class="size-6" />
        </button>
      </div>
    </div>
    """
  end

  defp space_form(scope) do
    Space
    |> AshPhoenix.Form.for_create(:create, as: "space", scope: scope)
    |> to_form()
  end
end
