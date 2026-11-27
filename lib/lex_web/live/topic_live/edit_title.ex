defmodule LexWeb.TopicLive.EditTitle do
  use LexWeb, :live_view
  use LiveDelegate, path: [:edit_title]

  alias LexWeb.Components.ResourceRename
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
    <ResourceRename.button_edit event={delegate_event("open")} aria-label="Edit topic name" />
    """
  end

  attr :edit_title, :map, required: true

  def render_form(assigns) do
    ~H"""
    <ResourceRename.render_form
      id="topic-title-form"
      form={@edit_title.form}
      field={@edit_title.form[:name]}
      label="Topic name"
      path_prefix="/topics/"
      change_event={delegate_event("change")}
      save_event={delegate_event("save")}
      cancel_event={delegate_event("cancel")}
    >
      <:actions>
        <button
          type="button"
          class="btn btn-error"
          data-confirm={~s(Are you sure you want to delete "#{@edit_title.form.data.name}"?)}
          phx-click={delegate_event("delete")}
          phx-disable-with="Deleting..."
        >
          Delete
        </button>
      </:actions>
    </ResourceRename.render_form>
    """
  end

  defp title_form(scope, topic) do
    topic
    |> AshPhoenix.Form.for_update(:rename, as: "topic_title", scope: scope)
    |> to_form()
  end
end
