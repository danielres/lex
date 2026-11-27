defmodule LexWeb.TopicsLive.Creation do
  use LexWeb, :live_view
  use LiveDelegate, path: [:creation]

  alias Lex.Topics.Graph
  alias Lex.Topics.Topic
  alias LexWeb.Components.Combobox

  def on_mount(_params, _session, socket) do
    socket
    |> delegate_assign(%{parent_form: make_parent_form()})
    |> reset_topic_form()
  end

  def select_parent(socket, parent_id) do
    parent_form = make_parent_form(%{"parent_id" => parent_id})
    delegate_assign(socket, :parent_form, parent_form)
  end

  defp reset_topic_form(socket) do
    scope = socket.assigns.scope
    topic_form = make_topic_form(scope)

    delegate_assign(socket, :form, topic_form)
  end

  defp make_topic_form(scope) do
    Topic
    |> AshPhoenix.Form.for_create(:create, as: "topic", scope: scope)
    |> to_form()
  end

  defp make_parent_form(params \\ %{}) do
    to_form(params, as: :parent)
  end

  @impl true
  def handle_event("validate", %{"topic" => params} = payload, socket) do
    topic_form = AshPhoenix.Form.validate(socket.assigns.creation.form, params)
    parent_params = Map.get(payload, "parent", %{})
    parent_form = make_parent_form(parent_params)

    socket =
      socket
      |> delegate_assign(:form, topic_form)
      |> delegate_assign(:parent_form, parent_form)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"topic" => params} = payload, socket) do
    topic_form = socket.assigns.creation.form
    parent_id = get_in(payload, ["parent", "parent_id"])

    case topic_form |> AshPhoenix.Form.submit(params: params) do
      {:ok, topic} ->
        handle_created_topic(socket, topic, parent_id)

      {:error, topic_form} ->
        socket = socket |> delegate_assign(:form, topic_form)
        {:noreply, socket}
    end
  end

  attr :class, :string, default: ""
  attr :creation, :map, required: true
  attr :topics, :list, required: true

  def render_form(assigns) do
    options =
      [%{label: "No parent", value: ""}] ++
        (assigns.topics
         |> Enum.sort_by(&String.downcase(&1.name))
         |> Enum.map(&%{label: &1.name, value: &1.id}))

    suggested_values = options |> Enum.map(& &1.value) |> Enum.take(8)

    assigns =
      assigns
      |> assign(:options_json, Jason.encode!(options))
      |> assign(:suggested_values_json, Jason.encode!(suggested_values))

    ~H"""
    <.form
      class={[
        @class,
        "space-y-2"
      ]}
      for={@creation.form}
      id="topic-form"
      phx-change={delegate_event("validate")}
      phx-submit={delegate_event("save")}
    >
      <div class="max-w-64">
        <Combobox.field
          empty_display="No parent"
          empty_message="No matching topic"
          field={@creation.parent_form[:parent_id]}
          id="topic-parent"
          label="Parent (optional)"
          options_json={@options_json}
          placeholder="Search topics"
          suggested_values_json={@suggested_values_json}
        />
      </div>

      <.input
        field={@creation.form[:name]}
        placeholder="New topic name"
        phx-mounted={JS.focus()}
        autocomplete="off"
        phx-hook="CapitalizeFirstLetter"
      />

      <div class="flex justify-end">
        <button type="submit" phx-disable-with="Saving..." class="btn btn-info">
          Add topic
        </button>
      </div>
    </.form>
    """
  end

  defp handle_created_topic(socket, topic, parent_id) when parent_id in [nil, ""] do
    socket =
      socket
      |> reset_topic_form()
      |> Toast.put_toast(:info, ~s(Added topic "#{topic.name}"))

    {:noreply, socket}
  end

  defp handle_created_topic(socket, topic, parent_id) do
    case Graph.attach(parent_id, topic.id, scope: socket.assigns.scope) do
      {:ok, _graph} ->
        socket =
          socket
          |> reset_topic_form()
          |> Toast.put_toast(:info, ~s(Added topic "#{topic.name}"))

        {:noreply, socket}

      {:error, _error} ->
        socket =
          socket
          |> reset_topic_form()
          |> Toast.put_toast(
            :error,
            ~s(Added topic "#{topic.name}", but could not attach it to its parent)
          )

        {:noreply, socket}
    end
  end
end
