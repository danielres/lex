defmodule LexWeb.PageLive.EditTitle do
  use LexWeb, :live_view
  use LiveDelegate, path: [:edit_title]

  alias LexWeb.Live.Components

  def on_mount(_params, _session, socket) do
    delegate_assign(socket, %{form: nil})
  end

  def reload(socket, page) do
    scope = socket.assigns.scope

    form =
      if can?(scope, :edit_pages) do
        scope |> title_form(page)
      end

    socket |> delegate_assign(:form, form)
  end

  @impl true
  def handle_event("open", _params, socket) do
    page = socket.assigns.page

    socket =
      socket
      |> reload(page)
      |> assign(live_action: :edit_title)

    {:noreply, socket}
  end

  def handle_event("cancel", _params, socket) do
    socket = socket |> assign(live_action: :info)

    {:noreply, socket}
  end

  def handle_event(event, _params, %{assigns: %{edit_title: %{form: nil}}} = socket)
      when event in ["change", "save"] do
    {:noreply, socket}
  end

  def handle_event("change", %{"page_title" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.edit_title.form, params)
    socket = socket |> delegate_assign(:form, form)

    {:noreply, socket}
  end

  def handle_event("save", %{"page_title" => params}, socket) do
    socket.assigns.edit_title.form
    |> AshPhoenix.Form.submit(params: params)
    |> case do
      {:ok, _page} ->
        {:noreply, socket}

      {:error, form} ->
        socket =
          socket
          |> delegate_assign(:form, form)
          |> push_event("page_title_blur", %{})

        {:noreply, socket}
    end
  end

  def button_edit(assigns) do
    ~H"""
    <button
      type="button"
      class="clickable"
      data-testid="edit-title-button"
      phx-click={delegate_event("open")}
    >
      <.icon name="hero-pencil-micro" />
    </button>
    """
  end

  attr :edit_title, :map, required: true

  def render_form(assigns) do
    ~H"""
    <h2 class={[
      "small-caps text-lg",
      "mb-2"
    ]}>
      <span>Page name and path</span>
    </h2>

    <.form
      for={@edit_title.form}
      data-testid="edit-title-form"
      id="page-title-form"
      phx-change={delegate_event("change")}
      phx-submit={delegate_event("save")}
      tabindex="-1"
      class="space-y-2"
    >
      <input
        aria-label="Page title"
        autocomplete="off"
        class={[
          "input input-lg w-full"
        ]}
        id={@edit_title.form[:title].id}
        name={@edit_title.form[:title].name}
        phx-hook="CapitalizeFirstLetter"
        phx-key="Escape"
        phx-keydown={delegate_event("cancel")}
        value={@edit_title.form[:title].value}
        phx-mounted={JS.focus() |> JS.dispatch("focus-at-end")}
      />

      <Components.slug_preview form={@edit_title.form} prefix="/wiki/" />

      <p
        :for={{message, _options} <- @edit_title.form[:title].errors}
        class="mt-1.5 flex items-center gap-2 text-sm text-error"
      >
        <.icon name="hero-exclamation-circle" class="size-5" />
        {message}
      </p>

      <div class="flex justify-between">
        <button
          aria-label="Cancel title change"
          class="btn btn-soft"
          data-testid="edit-title-cancel"
          phx-click={delegate_event("cancel")}
          type="button"
        >
          Cancel
        </button>

        <button
          aria-label="Save page title"
          class="btn btn-info"
          type="submit"
        >
          Update
        </button>
      </div>
    </.form>
    """
  end

  defp title_form(scope, page) do
    page
    |> AshPhoenix.Form.for_update(:rename, as: "page_title", scope: scope)
    |> to_form()
  end
end
