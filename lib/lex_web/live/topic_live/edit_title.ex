defmodule LexWeb.TopicLive.EditTitle do
  use LexWeb, :live_view
  use LiveDelegate, path: [:edit_title]

  alias LexWeb.Live.Components
  alias LexWeb.Router.Path

  def on_mount(_params, _session, socket) do
    delegate_assign(socket, %{form: nil})
  end

  @impl true
  def handle_event("open", _params, socket) do
    %{scope: scope, topic: topic} = socket.assigns

    socket =
      socket
      |> delegate_assign(:form, title_form(scope, topic))
      |> assign(live_action: :edit_title)

    {:noreply, socket}
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, assign(socket, live_action: :info)}
  end

  def handle_event(event, _params, %{assigns: %{live_action: action}} = socket)
      when event in ["change", "save", "delete"] and action != :edit_title do
    {:noreply, socket}
  end

  def handle_event("change", %{"topic_title" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.edit_title.form, params)
    {:noreply, delegate_assign(socket, :form, form)}
  end

  def handle_event("save", %{"topic_title" => params}, socket) do
    form = socket.assigns.edit_title.form

    case form |> AshPhoenix.Form.submit(params: params) do
      {:ok, topic} ->
        scope = socket.assigns.scope

        socket =
          socket
          |> Toast.put_toast(:info, ~s(Renamed topic to "#{topic.name}"))
          |> push_navigate(to: Path.to(scope, topic))

        {:noreply, socket}

      {:error, form} ->
        socket = socket |> delegate_assign(:form, form)
        {:noreply, socket}
    end
  end

  def handle_event("delete", _params, socket) do
    scope = socket.assigns.scope
    topic = socket.assigns.topic

    case Ash.destroy(topic, scope: scope) do
      :ok ->
        socket =
          socket
          |> Toast.put_toast(:info, ~s(Deleted topic "#{topic.name}"))
          |> push_navigate(to: Path.topics(scope))

        {:noreply, socket}

      {:error, _error} ->
        {:noreply, Toast.put_toast(socket, :error, "Could not delete topic")}
    end
  end

  def button_edit(assigns) do
    ~H"""
    <button
      type="button"
      class="clickable"
      aria-label="Edit topic name"
      phx-click={delegate_event("open")}
    >
      <.icon name="hero-pencil-micro" />
    </button>
    """
  end

  attr :edit_title, :map, required: true

  def render_form(assigns) do
    ~H"""
    <.form
      for={@edit_title.form}
      id="topic-title-form"
      phx-change={delegate_event("change")}
      phx-submit={delegate_event("save")}
      tabindex="-1"
      class="space-y-2"
    >
      <.input
        field={@edit_title.form[:name]}
        aria-label="Topic name"
        class="input input-lg w-full"
        phx-mounted={JS.focus() |> JS.dispatch("focus-at-end")}
        autocomplete="off"
        phx-hook="CapitalizeFirstLetter"
        phx-key="Escape"
        phx-keydown={delegate_event("cancel")}
      />

      <Components.slug_preview form={@edit_title.form} prefix="/topics/" />

      <div class="flex gap-2">
        <button
          type="button"
          class="btn btn-error"
          data-confirm={~s(Are you sure you want to delete "#{@edit_title.form.data.name}"?)}
          phx-click={delegate_event("delete")}
          phx-disable-with="Deleting..."
        >
          Delete
        </button>

        <button
          type="button"
          class="btn btn-ghost ml-auto"
          phx-click={delegate_event("cancel")}
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

  defp title_form(scope, topic) do
    topic
    |> AshPhoenix.Form.for_update(:update, as: "topic_title", scope: scope)
    |> to_form()
  end
end
