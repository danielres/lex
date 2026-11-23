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
      <div
        phx-click-away={if @mode == :creation, do: "mode:reset"}
        phx-key="escape"
        phx-window-keydown={if @mode == :creation, do: "mode:reset"}
      >
        <Layouts.page_head dialog?={@mode == :creation}>
          <:title>Topics</:title>
          <:actions><.action_buttons mode={@mode} /></:actions>
          <:dialog><Creation.render_form creation={@creation} topics={@graph.topics} /></:dialog>
        </Layouts.page_head>
      </div>

      <div inert={@mode == :creation}>
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
    <button
      :if={@mode == :view || @mode == :creation}
      type="button"
      phx-click="toggle_mode:creation"
      class={[
        "btn btn-circle btn-xs",
        @mode == :creation && "btn-info"
      ]}
    >
      <.icon :if={@mode == :view} name="hero-plus-micro" />
      <.icon :if={@mode == :creation} name="hero-x-mark-micro" />
    </button>

    <button
      :if={@mode == :view || @mode == :edit}
      type="button"
      phx-click="toggle_mode:edit"
      class={[
        "btn btn-circle btn-xs",
        @mode == :edit && "btn-info"
      ]}
    >
      <.icon :if={@mode == :view} name="hero-pencil-micro" />
      <.icon :if={@mode == :edit} name="hero-x-mark-micro" />
    </button>
    """
  end
end
