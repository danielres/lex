defmodule LexWeb.TopicsLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias Lex.Topics
  alias LexWeb.Layouts
  alias LexWeb.TopicsLive.Creation
  alias LexWeb.TopicsLive.Graph
  alias LexWeb.UI

  delegate(:creation, Creation)
  delegate(:graph, Graph)
  delegate(:ui, UI)

  @impl true
  def mount(params, session, socket) do
    socket =
      socket
      |> assign(mode: :view)
      |> delegate_mount(params, session)

    {:ok, socket}
  end

  @impl true
  def handle_info(%{resource: Topics.Graph} = msg, socket) do
    Graph.handle_info(msg, socket)
  end

  @impl true
  def handle_info(%{resource: Topics.Topic} = msg, socket) do
    Graph.handle_info(msg, socket)
  end

  def handle_event("toggle_mode:creation", _params, socket) do
    mode = if socket.assigns.mode == :creation, do: :view, else: :creation
    socket = socket |> assign(mode: mode)
    {:noreply, socket}
  end

  def handle_event("toggle_mode:edit", _params, socket) do
    mode = if socket.assigns.mode == :edit, do: :view, else: :edit
    socket = socket |> assign(mode: mode)
    {:noreply, socket}
  end

  def handle_event("mode:reset", _params, socket) do
    socket = socket |> assign(mode: :view)
    {:noreply, socket}
  end

  def handle_event("add_children", %{"parent-id" => parent_id}, socket) do
    socket =
      socket
      |> Creation.select_parent(parent_id)
      |> assign(:mode, :creation)

    {:noreply, socket}
  end

  defp dialog?(mode), do: mode == :creation

  @impl true
  def render(assigns) do
    focus_topic_id =
      if assigns.mode == :creation do
        parent_form = assigns.creation.parent_form
        parent_form |> Phoenix.HTML.Form.input_value(:parent_id)
      end

    assigns = assigns |> assign(focus_topic_id: focus_topic_id)

    ~H"""
    <Layouts.app
      active="topics"
      flash={@flash}
      scope={@scope}
      socket={@socket}
      ui={@ui}
    >
      <:page_head>
        <Layouts.page_head
          close_event={@mode != :view && "mode:reset"}
          dialog?={dialog?(@mode)}
        >
          <:crumb><span class="opacity-80">Topics</span></:crumb>
          <:title>Overview</:title>
          <:actions><.action_buttons mode={@mode} /></:actions>
          <:dialog :if={dialog?(@mode)}>
            <Creation.render_form creation={@creation} topics={@graph.topics} />
          </:dialog>
        </Layouts.page_head>
      </:page_head>

      <div inert={dialog?(@mode)} class="sm:-ml-1">
        <Graph.render
          edit?={@mode == :edit}
          focus_topic_id={@focus_topic_id}
          graph={@graph}
          scope={@scope}
        />
      </div>
    </Layouts.app>
    """
  end

  attr :mode, :atom, required: true

  def action_buttons(assigns) do
    ~H"""
    <Layouts.action_button
      active?={@mode == :creation}
      icon="hero-plus-micro"
      phx-click="toggle_mode:creation"
      title="Add topic"
    />

    <Layouts.action_button
      active?={@mode == :edit}
      icon="hero-pencil-micro"
      phx-click="toggle_mode:edit"
      title="Edit topic"
    />
    """
  end
end
