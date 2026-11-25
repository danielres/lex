defmodule LexWeb.TopicsLive.Graph do
  use LexWeb, :live_view
  use LiveDelegate, path: [:graph]

  require Logger

  alias Lex.Scope
  alias Lex.Topics.Graph
  alias Lex.Topics.Topic
  alias LexWeb.Router.Path
  alias LexWeb.TopicsLive.Graph.Attachment

  delegate(:attachment, Attachment)

  def on_mount(params, session, socket) do
    socket
    |> subscribe()
    |> delegate_assign(%{
      children: %{},
      tree: [],
      topics: []
    })
    |> reload_data()
    |> delegate_mount(params, session)
  end

  @impl true
  def handle_event("detach", %{"parent-id" => parent_id, "child-id" => child_id}, socket) do
    case Graph.detach(parent_id, child_id, scope: socket.assigns.scope) do
      {:ok, _graph} ->
        socket =
          socket
          |> reload_data()
          |> Toast.put_toast(:info, "Topic detached")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, Toast.put_toast(socket, :error, graph_error(reason))}
    end
  end

  defp graph_error(:cycle), do: "That would create a cycle"
  defp graph_error(:invalid_topics), do: "Topics must belong to this space"
  defp graph_error(:self_link), do: "A topic cannot be its own child"
  defp graph_error(_error), do: "Could not update topic graph"

  @impl true
  def handle_info(%{action: %{name: action}}, socket)
      when action in [:create, :update, :destroy] do
    {:noreply, reload_data(socket)}
  end

  attr :edit?, :boolean, required: true
  attr :focus_topic_id, :string, required: true
  attr :graph, :map, required: true
  attr :patch?, :boolean, default: false
  attr :scope, Scope, required: true

  @impl true
  def render(assigns) do
    child_id = assigns.graph.attachment.child_id
    focus_topic_id = assigns.focus_topic_id
    topics = assigns.graph.topics
    tree = assigns.graph.tree

    selected_child = topics |> Enum.find(&(&1.id == child_id))
    tree = tree |> Graph.focus(focus_topic_id)

    parent_candidate_ids =
      if selected_child do
        children = assigns.graph.children

        topics
        |> Graph.parent_candidates(children, child_id)
        |> MapSet.new(& &1.id)
      else
        MapSet.new()
      end

    assigns =
      assigns
      |> assign(:parent_candidate_ids, parent_candidate_ids)
      |> assign(:selected_child, selected_child)
      |> assign(:tree, tree)

    ~H"""
    <div
      :if={@selected_child}
      class={[
        "flex items-center justify-between gap-4",
        "bg-base-200 pl-4 pr-2 py-2 rounded-box",
        "border border-info",
        "fixed max-w-sm right-4 top-4"
      ]}
    >
      <p>
        Please choose a new parent for <span class="font-semibold">{@selected_child.name}</span>
      </p>
      <button
        type="button"
        class="btn btn-info btn-sm"
        phx-click={delegate_event("attachment:cancel")}
      >
        Cancel
      </button>
    </div>

    <div class="space-y-4">
      <p :if={@tree == []} class="text-base-content/60">No topics yet</p>

      <ul
        :if={@tree != []}
        id="topic-graph"
        phx-hook="AutoAnimate"
        class="relative"
      >
        <.topic_node
          :for={node <- @tree}
          scope={@scope}
          attaching?={not is_nil(@selected_child)}
          focus_topic_id={@focus_topic_id}
          node={node}
          parent_candidate_ids={@parent_candidate_ids}
          patch?={@patch?}
          edit?={@edit?}
        />
      </ul>
    </div>
    """
  end

  attr :attaching?, :boolean, required: true
  attr :edit?, :boolean, required: true
  attr :focus_topic_id, :string, required: true
  attr :node, :map, required: true
  attr :parent_candidate_ids, :any, required: true
  attr :scope, Scope, required: true
  attr :patch?, :boolean, required: true

  def topic_node(assigns) do
    assigns =
      assign(
        assigns,
        :parent_candidate?,
        MapSet.member?(assigns.parent_candidate_ids, assigns.node.topic.id)
      )

    ~H"""
    <li id={@node.dom_id} phx-hook="AutoAnimate">
      <div class={[
        "flex items-center gap-8 transition rounded",
        !@attaching? && @edit? && "opacity-80 hover:opacity-100 transition hover:bg-base-300/20",
        @attaching? && @parent_candidate? && "hover:bg-info",
        @attaching? && !@parent_candidate? && "opacity-30"
      ]}>
        <button
          :if={@attaching? && @parent_candidate?}
          type="button"
          class={[
            "text-left cursor-pointer",
            "grow",
            "py-1 px-2"
          ]}
          phx-click={delegate_event("attachment:choose_parent")}
          phx-value-parent-id={@node.topic.id}
          aria-label={"Choose #{@node.topic.name} as parent"}
        >
          {@node.topic.name}
        </button>

        <.link
          :if={not @attaching? or not @parent_candidate?}
          navigate={if !@patch?, do: Path.to(@scope, @node.topic)}
          patch={if @patch?, do: Path.to(@scope, @node.topic)}
          class={["grow", "py-1 px-2", "group", "leading-tight"]}
        >
          <span class={[
            "opacity-80 group-hover:opacity-100 transition",
            @focus_topic_id == @node.topic.id && "font-bold opacity-100"
          ]}>
            {@node.topic.name}
          </span>
        </.link>

        <div :if={not @attaching? && @edit?} class="flex gap-2">
          <button
            :if={@node.parent_id}
            type="button"
            class="btn btn-circle btn-xs hover:btn-info"
            phx-click={delegate_event("detach")}
            phx-value-parent-id={@node.parent_id}
            phx-value-child-id={@node.topic.id}
            aria-label={"Detach #{@node.topic.name}"}
          >
            <.icon name="hero-link-slash-micro" />
          </button>

          <button
            type="button"
            class="btn btn-circle btn-xs hover:btn-info"
            phx-click="add_children"
            phx-value-parent-id={@node.topic.id}
            aria-label={"Add children under #{@node.topic.name}"}
          >
            <.icon name="hero-plus-micro" />
          </button>

          <button
            type="button"
            class="btn btn-circle btn-xs hover:btn-info"
            phx-click={delegate_event("attachment:start")}
            phx-value-child-id={@node.topic.id}
            aria-label={"Attach #{@node.topic.name} under another topic"}
          >
            <.icon name="hero-arrow-turn-down-right-micro" />
          </button>
        </div>
      </div>

      <ul
        :if={@node.children != []}
        id={"#{@node.dom_id}-children"}
        phx-hook="AutoAnimate"
        class="relative border-l border-base-content/20 pl-4 ml-2"
      >
        <.topic_node
          :for={child <- @node.children}
          edit?={@edit?}
          focus_topic_id={@focus_topic_id}
          attaching?={@attaching?}
          patch?={@patch?}
          node={child}
          parent_candidate_ids={@parent_candidate_ids}
          scope={@scope}
        />
      </ul>
    </li>
    """
  end

  defp reload_data(socket) do
    scope = socket.assigns.scope

    # Read the graph first so newly referenced topics cannot be mistaken for dangling IDs.
    graph = Graph |> Ash.read_one!(scope: scope)
    topics = Topic |> Ash.read!(scope: scope)

    children = repair_graph_children(graph, topics, scope)
    tree = Graph.tree(topics, children)

    socket
    |> delegate_assign(:children, children)
    |> delegate_assign(:tree, tree)
    |> delegate_assign(:topics, topics)
  end

  defp repair_graph_children(nil, _topics, _scope), do: %{}

  defp repair_graph_children(graph, topics, scope) do
    case Graph.repair(graph, topics, scope: scope) do
      {:ok, graph} ->
        graph.children

      {:error, error} ->
        Logger.warning("Could not repair topic graph #{graph.id}: #{inspect(error)}")
        Graph.normalize_children(topics, graph.children)
    end
  end

  defp subscribe(socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Lex.PubSub, "topics:topics")
      Phoenix.PubSub.subscribe(Lex.PubSub, "topics:graphs:#{socket.assigns.scope.space.id}")
    end

    socket
  end
end
