defmodule LexWeb.Live.Rename do
  use LexWeb, :live_view
  use LiveDelegate, path: [:rename]

  alias LexWeb.Live.Components

  def on_mount(_params, _session, socket), do: delegate_assign(socket, %{form: nil})

  def open(socket, resource) do
    form =
      resource
      |> AshPhoenix.Form.for_update(:rename, as: "rename", scope: socket.assigns.scope)
      |> to_form()

    socket
    |> delegate_assign(:form, form)
    |> assign(:live_action, :rename)
  end

  def clear(socket), do: delegate_assign(socket, :form, nil)

  @impl true
  def handle_event("cancel", _params, %{assigns: %{live_action: :rename}} = socket) do
    {:noreply, socket |> clear() |> assign(:live_action, :info)}
  end

  def handle_event("change", %{"rename" => params}, %{assigns: %{live_action: :rename}} = socket) do
    form = AshPhoenix.Form.validate(socket.assigns.rename.form, params)
    {:noreply, delegate_assign(socket, :form, form)}
  end

  def handle_event("save", %{"rename" => params}, %{assigns: %{live_action: :rename}} = socket) do
    form = socket.assigns.rename.form

    case AshPhoenix.Form.submit(form, params: params) do
      {:ok, updated} ->
        socket =
          if updated.name == form.data.name && updated.slug == form.data.slug do
            socket |> clear() |> assign(:live_action, :show)
          else
            socket
          end

        {:noreply, socket}

      {:error, form} ->
        {:noreply, delegate_assign(socket, :form, form)}
    end
  end

  def handle_event(event, _params, socket) when event in ["open", "cancel", "change", "save", "delete"],
    do: {:noreply, socket}

  def apply_change(socket, previous, updated, label, path) do
    socket =
      if socket.assigns.live_action == :rename do
        socket |> clear() |> assign(:live_action, :show)
      else
        socket
      end

    socket =
      if previous.name != updated.name do
        Toast.put_toast(socket, :info, ~s(#{label} "#{previous.name}" was renamed to "#{updated.name}"))
      else
        socket
      end

    if path && previous.slug != updated.slug do
      push_patch(socket, to: path, replace: true)
    else
      socket
    end
  end

  def delete(socket, resource, label, path) do
    case Ash.destroy(resource, scope: socket.assigns.scope) do
      :ok ->
        socket
        |> Toast.put_toast(:info, ~s(Deleted #{label} "#{resource.name}"))
        |> push_navigate(to: path)

      {:error, _error} ->
        Toast.put_toast(socket, :error, "Could not delete #{label}")
    end
  end

  attr :label, :string, required: true

  def button_edit(assigns) do
    ~H"""
    <button type="button" class="clickable" aria-label={@label} data-testid="rename-open" phx-click={delegate_event("open")}>
      <.icon name="hero-pencil-micro" />
    </button>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :label, :string, required: true
  attr :path_prefix, :string, required: true
  attr :deletable?, :boolean, default: false

  def render_form(assigns) do
    assigns = assign(assigns, :field, assigns.form[:name])

    ~H"""
    <.form
      for={@form}
      id="rename-form"
      data-testid="rename-form"
      phx-change={delegate_event("change")}
      phx-key="Escape"
      phx-submit={delegate_event("save")}
      phx-window-keydown={delegate_event("cancel")}
      tabindex="-1"
      class="space-y-2"
    >
      <input
        aria-label={@label}
        autocomplete="off"
        class={["input input-lg w-full", @field.errors != [] && "input-error"]}
        id={@field.id}
        name={@field.name}
        phx-hook="CapitalizeFirstLetter"
        value={@field.value}
        phx-mounted={JS.focus() |> JS.dispatch("focus-at-end")}
      />

      <Components.slug_preview form={@form} prefix={@path_prefix} />

      <p
        :for={{message, _options} <- @field.errors}
        class="mt-1.5 flex items-center gap-2 text-sm text-error"
      >
        <.icon name="hero-exclamation-circle" class="size-5" />
        {message}
      </p>

      <div class="flex gap-2">
        <button
          :if={@deletable?}
          type="button"
          class="btn btn-error"
          data-confirm={~s(Are you sure you want to delete "#{@form.data.name}"?)}
          phx-click={delegate_event("delete")}
          phx-disable-with="Deleting..."
        >
          Delete
        </button>

        <button
          class="btn btn-ghost ml-auto"
          data-testid="rename-cancel"
          phx-click={delegate_event("cancel")}
          type="button"
        >
          Cancel
        </button>

        <button type="submit" phx-disable-with="Saving..." class="btn btn-info">
          Rename
        </button>
      </div>
    </.form>
    """
  end
end
