defmodule LexWeb.HomeLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias Lex.Accounts.Space
  alias LexWeb.UI

  delegate(:ui, UI)

  @impl true
  def mount(params, session, socket) do
    socket = socket |> delegate_mount(params, session)
    scope = socket.assigns.scope

    space_form = scope |> space_form()
    spaces = Space.list!(scope: scope)

    socket =
      socket
      |> assign(:creating_space?, false)
      |> assign(:space_form, space_form)
      |> assign(:spaces, spaces)

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
        scope = socket.assigns.scope
        space_form = scope |> space_form()

        socket =
          socket
          |> assign(:creating_space?, false)
          |> assign(:space_form, space_form)
          |> update(:spaces, fn spaces ->
            Enum.sort_by([space | spaces], & &1.name)
          end)

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
        <h1
          :if={!@creating_space?}
          class="text-xl font-semibold border-b border-base-content/20 pb-2 mb-4"
        >
          Your spaces
        </h1>

        <div :if={!@creating_space?} class="flex flex-wrap gap-2">
          <.link
            :for={space <- @spaces}
            navigate={~p"/#{space.slug}"}
            data-testid="space"
            class={[
              "p-4",
              "block",
              "size-32",
              "bg-base-100 rounded",
              "opacity-80 hover:opacity-100 transition",
              "font-semibold",
              "flex items-center justify-center"
            ]}
          >
            {space.name}
          </.link>

          <button
            type="button"
            phx-click="show_space_form"
            data-testid="show-space-form"
            class={[
              "p-4",
              "block",
              "size-32",
              "bg-base-100 rounded",
              "opacity-80 hover:opacity-100 hover:bg-info transition",
              "cursor-pointer"
            ]}
          >
            <.icon name="hero-plus-micro" class="size-6" />
          </button>
        </div>

        <.form
          :if={@creating_space?}
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
