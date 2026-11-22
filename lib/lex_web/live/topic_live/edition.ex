defmodule LexWeb.TopicLive.Edition do
  use LexWeb, :live_view
  use LiveDelegate, path: [:edition]

  alias LexWeb.Live.Components
  alias LexWeb.Router.Path

  def on_mount(_params, _session, socket) do
    socket |> reload_form()
  end

  defp reload_form(socket) do
    scope = socket.assigns.scope
    topic = socket.assigns.topic
    form = make_form(topic, scope)
    socket |> delegate_assign(%{form: form})
  end

  @impl true
  def handle_event("validate", %{"topic" => params}, socket) do
    form = socket.assigns.edition.form
    form = form |> AshPhoenix.Form.validate(params)
    socket = socket |> delegate_assign(:form, form)
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"topic" => params}, socket) do
    form = socket.assigns.edition.form

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

  @impl true
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

  attr :class, :string, default: ""
  attr :edition, :map, required: true

  def render_form(assigns) do
    ~H"""
    <.form
      class={[
        @class,
        "grid gap-2"
      ]}
      for={@edition.form}
      id="topic-form"
      phx-change={delegate_event("validate")}
      phx-submit={delegate_event("save")}
    >
      <.input
        field={@edition.form[:name]}
        placeholder="New name"
        phx-mounted={JS.focus() |> JS.dispatch("focus-at-end")}
        autocomplete="off"
        phx-hook="CapitalizeFirstLetter"
      />

      <Components.slug_preview form={@edition.form} prefix="/topics/" />

      <div class="flex gap-2 justify-between">
        <button
          type="button"
          class="btn btn-error btn-soft"
          data-confirm={~s(Are you sure you want to delete "#{@edition.form.data.name}"?)}
          phx-click={delegate_event("delete")}
          phx-disable-with="Deleting..."
        >
          Delete
        </button>
        <button type="submit" phx-disable-with="Saving..." class="btn btn-info">
          Rename
        </button>
      </div>
    </.form>
    """
  end

  defp make_form(topic, scope) do
    topic
    |> AshPhoenix.Form.for_update(:update, as: "topic", scope: scope)
    |> to_form()
  end
end
