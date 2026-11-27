defmodule LexWeb.TopicLive do
  use LexWeb, :live_view
  use LiveDelegate

  alias Lex.Topics
  alias Lex.Topics.Tagging
  alias Lex.Topics.Topic
  alias LexWeb.Layouts
  alias LexWeb.Router.Path
  alias LexWeb.Live.Rename
  alias LexWeb.TopicLive.Info
  alias LexWeb.TopicLive.Taggings
  alias LexWeb.TopicsLive.Graph
  alias LexWeb.UI

  delegate(:rename, Rename, info: false)
  delegate(:graph, Graph)
  delegate(:info, Info, info: false, mount: false)
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
          |> assign(topic: topic)
          |> Rename.clear()
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

  @impl true
  def handle_info(
        %{resource: Topic, action: %{name: :rename}, data: %Topic{id: id}} = message,
        %{assigns: %{topic: %Topic{id: id} = previous, scope: scope}} = socket
      ) do
    {:noreply, socket} = Graph.handle_info(message, socket)

    case Ash.get(Topic, id, load: [:author], scope: scope) do
      {:ok, topic} when topic.name != previous.name or topic.slug != previous.slug ->
        socket =
          socket
          |> assign(:topic, topic)
          |> Rename.apply_change(previous, topic, "Topic", Path.to(scope, topic))

        {:noreply, socket}

      _result ->
        {:noreply, socket}
    end
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

  @impl true
  def handle_info(%{resource: Topic} = msg, socket) do
    Graph.handle_info(msg, socket)
  end

  @impl true
  def handle_info(%{resource: Tagging} = msg, socket) do
    Taggings.handle_info(msg, socket)
  end

  @impl true
  def handle_event("toggle_sort_taggings", _params, socket) do
    live_action =
      case socket.assigns.live_action do
        :sort_taggings -> :show
        _ -> :sort_taggings
      end

    {:noreply, socket |> Rename.clear() |> assign(:live_action, live_action)}
  end

  @impl true
  def handle_event(
        "rename:open",
        _params,
        %{assigns: %{live_action: :info, topic: %Topic{} = topic, scope: scope}} = socket
      ) do
    if Ash.can?({topic, :rename}, scope) do
      {:noreply, Rename.open(socket, topic)}
    else
      {:noreply, socket}
    end
  end

  def handle_event(
        "rename:delete",
        _params,
        %{assigns: %{live_action: :rename, topic: topic, scope: scope}} = socket
      ) do
    {:noreply, Rename.delete(socket, topic, "topic", Path.topics(scope))}
  end

  def handle_event("close_dialog", _params, socket) do
    {:noreply, socket |> Rename.clear() |> assign(:live_action, :show)}
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
      <:page_head>
        <Layouts.page_head
          close_event={@live_action != :show && "close_dialog"}
          dialog?={@live_action != :show}
        >
          <:crumb>
            <.link navigate={Path.topics(@scope)} class="opacity-80 hover:opacity-100 transition">Topics</.link>
          </:crumb>
          <:title>
            {@topic.name}

            <span class="ml-2">
              <Rename.button_edit label="Edit topic name" :if={
                @live_action == :info && Ash.can?({@topic, :rename}, @scope)
              } />
            </span>
          </:title>
          <:actions>
            <.action_buttons
              live_action={@live_action}
              sortable?={@taggings.status == :ready}
            />
          </:actions>
          <:dialog>
            <div :if={@live_action == :rename} class="pt-4">
              <Rename.render_form
                form={@rename.form}
                label="Topic name"
                path_prefix="/topics/"
                deletable?={Ash.can?({@topic, :destroy}, @scope)}
              />
            </div>
            <Info.render :if={@live_action == :info} topic={@topic} scope={@scope} />
            <Taggings.render_sorting :if={@live_action == :sort_taggings} taggings={@taggings} />
          </:dialog>
        </Layouts.page_head>
      </:page_head>

      <div class="sm:flex gap-3" inert={@live_action == :sort_taggings}>
        <div class="space-y-4 min-w-0 grow">
          <Taggings.render scope={@scope} taggings={@taggings} />
          <%!-- <p>Added: {Utils.Time.relative(@topic.inserted_at)}</p> --%>
        </div>

        <hr
          :if={@taggings.members |> length() > 0}
          class="my-6 sm:hidden border-base-content/20 border-t-2"
        />

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
    |> Ash.Query.load(:author)
    |> Ash.read_one(not_found_error?: true, scope: scope)
  end

  attr :sortable?, :boolean, required: true
  attr :live_action, :atom, required: true

  def action_buttons(assigns) do
    ~H"""
    <Info.button_toggle active?={@live_action == :info || @live_action == :rename} />

    <Layouts.action_button
      active?={@live_action == :sort_taggings}
      icon="hero-arrows-up-down"
      phx-click="toggle_sort_taggings"
      title="Sort"
    />
    """
  end
end
