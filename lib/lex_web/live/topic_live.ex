defmodule LexWeb.TopicLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias Lex.Topics
  alias Lex.Topics.Tagging
  alias Lex.Topics.Topic
  alias LexWeb.Layouts
  alias LexWeb.Router.Path
  alias LexWeb.TopicLive.Edition
  alias LexWeb.TopicLive.Taggings
  alias LexWeb.TopicsLive.Graph
  alias LexWeb.UI

  delegate(:edition, Edition)
  delegate(:graph, Graph)
  delegate(:taggings, Taggings)
  delegate(:ui, UI)

  require Ash.Query

  @impl true
  def mount(params, session, socket) do
    scope = socket.assigns.scope
    slug = params["topic_slug"]
    result = find_topic(scope, slug)

    case result do
      {:ok, topic} ->
        socket =
          socket
          |> assign(:topic, topic)
          |> assign(:mode, :view)
          |> delegate_mount(params, session)

        {:ok, socket}

      {:error, _error} ->
        {:ok,
         socket
         |> assign(:topic, nil)
         |> Toast.put_toast(:error, "Topic not found")
         |> push_navigate(to: Path.to(scope.space))}
    end
  end

  @impl true
  def handle_params(%{"topic_slug" => slug}, _uri, socket) do
    scope = socket.assigns.scope

    case find_topic(scope, slug) do
      {:ok, topic} ->
        socket =
          socket
          |> assign(topic: topic, mode: :view)
          |> Edition.reload_form()
          |> Taggings.load_topic()

        {:noreply, socket}

      {:error, _error} ->
        {:noreply,
         socket
         |> Toast.put_toast(:error, "Topic not found")
         |> push_navigate(to: Path.to(scope.space))}
    end
  end

  @impl true
  def handle_info(%{resource: Topics.Graph} = msg, socket) do
    Graph.handle_info(msg, socket)
  end

  def handle_info(
        %{resource: Topic, action: %{name: :update}, data: %Topic{id: id} = topic},
        %{assigns: %{topic: %Topic{id: id, name: previous_name}, scope: scope}} = socket
      )
      when previous_name != topic.name do
    socket =
      socket
      |> Toast.put_toast(:info, "Topic #{previous_name} was renamed to #{topic.name}")
      |> push_navigate(to: Path.to(scope, topic), replace: true)

    {:noreply, socket}
  end

  def handle_info(
        %{resource: Topic, action: %{name: :destroy}, data: %Topic{id: id, name: name}},
        %{assigns: %{topic: %Topic{id: id}, scope: scope}} = socket
      ) do
    socket =
      socket
      |> Toast.put_toast(:info, "Topic #{name} was deleted")
      |> push_navigate(to: Path.topics(scope), replace: true)

    {:noreply, socket}
  end

  def handle_info(%{resource: Topic} = msg, socket) do
    Graph.handle_info(msg, socket)
  end

  def handle_info(%{resource: Tagging} = msg, socket) do
    Taggings.handle_info(msg, socket)
  end

  @impl true
  def handle_event("toggle_mode:edit", _params, socket) do
    mode = if socket.assigns.mode == :edit, do: :view, else: :edit
    socket = socket |> assign(mode: mode)
    {:noreply, socket}
  end

  def handle_event("sort_taggings", _params, socket) do
    {:noreply, assign(socket, :mode, :sort_taggings)}
  end

  def handle_event("close_dialog", _params, socket) do
    {:noreply, assign(socket, :mode, :view)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      active="topics"
      flash={@flash}
      scope={@scope}
      socket={@socket}
      ui={@ui}
    >
      <div
        phx-click-away={if @mode != :view, do: "close_dialog"}
        phx-key="escape"
        phx-window-keydown={if @mode != :view, do: "close_dialog"}
      >
        <Layouts.page_head dialog?={@mode != :view}>
          <:crumb>
            <.link navigate={Path.topics(@scope)} class="opacity-80 hover:opacity-100 transition">Topics</.link>
          </:crumb>
          <:title>{@topic.name}</:title>
          <:actions><.action_buttons mode={@mode} sortable?={@taggings.status == :ready} /></:actions>
          <:dialog>
            <Edition.render_form :if={@mode == :edit} edition={@edition} />
            <Taggings.render_sorting :if={@mode == :sort_taggings} taggings={@taggings} />
          </:dialog>
        </Layouts.page_head>
      </div>

      <div class="sm:flex gap-3" inert={@mode == :sort_taggings}>
        <div class="space-y-4 min-w-0 grow">
          <Taggings.render scope={@scope} taggings={@taggings} />
          <%!-- <p>Added: {Utils.Time.relative(@topic.inserted_at)}</p> --%>
        </div>

        <hr class="my-6 sm:hidden border-base-content/20 border-t-2" />

        <aside class="text-sm min-w-42">
          <Graph.render
            edit?={false}
            focus_topic_id={@topic.id}
            graph={@graph}
            patch?
            scope={@scope}
          />
        </aside>
      </div>
    </Layouts.app>
    """
  end

  defp find_topic(scope, slug) do
    Topic
    |> Ash.Query.filter(slug == ^slug)
    |> Ash.read_one(not_found_error?: true, scope: scope)
  end

  attr :mode, :atom, required: true
  attr :sortable?, :boolean, required: true

  def action_buttons(assigns) do
    ~H"""
    <button
      :if={@mode == :view && @sortable?}
      type="button"
      class="btn btn-circle btn-xs"
      phx-click="sort_taggings"
      aria-label="Sort"
    >
      <.icon name="hero-arrows-up-down" />
    </button>

    <button
      :if={@mode == :view}
      type="button"
      class="btn btn-circle btn-xs"
      phx-click="toggle_mode:edit"
      aria-label="Edit topic"
    >
      <.icon name="hero-pencil-micro" />
    </button>

    <button
      :if={@mode != :view}
      type="button"
      class="btn btn-circle btn-info btn-xs"
      phx-click="close_dialog"
      aria-label="Close dialog"
    >
      <.icon name="hero-x-mark-micro" />
    </button>
    """
  end
end
