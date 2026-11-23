defmodule Lex.Topics.Graph do
  alias Lex.Accounts
  alias Lex.Accounts.Membership.Checks.ActiveMember
  alias Lex.Topics.Topic

  use Ash.Resource,
    otp_app: :lex,
    domain: Lex.Topics,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  require Ash.Query

  postgres do
    table "topic_graphs"
    repo Lex.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept []
      primary? true
    end

    update :update do
      accept []
      primary? true
      require_atomic? false

      change optimistic_lock(:version)
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if ActiveMember
    end

    policy action(:create) do
      authorize_if ActiveMember
    end

    policy action(:update) do
      authorize_if ActiveMember
    end
  end

  pub_sub do
    module Phoenix.PubSub
    name Lex.PubSub
    prefix "topics"
    publish :create, ["graphs", :space_id]
    publish :update, ["graphs", :space_id]
  end

  multitenancy do
    strategy :attribute
    attribute :space_id
  end

  attributes do
    uuid_primary_key :id

    attribute :children, :map do
      allow_nil? false
      default %{}
      writable? false
    end

    attribute :version, :integer do
      allow_nil? false
      default 1
      writable? false
    end

    timestamps()
  end

  relationships do
    belongs_to :space, Accounts.Space, allow_nil?: false
  end

  identities do
    identity :unique_space, [:space_id]
  end

  def attach(parent_id, child_id, opts) do
    scope = Keyword.fetch!(opts, :scope)

    with :ok <- validate_topics(parent_id, child_id, scope),
         {:ok, graph} <- ensure_graph(scope),
         {:ok, children} <- attach_child(graph.children, parent_id, child_id) do
      persist_children(graph, children, scope)
    end
  end

  def detach(parent_id, child_id, opts) do
    scope = Keyword.fetch!(opts, :scope)

    with {:ok, graph} when not is_nil(graph) <- read_graph(scope),
         children <- detach_child(graph.children, parent_id, child_id) do
      persist_children(graph, children, scope)
    else
      {:ok, nil} -> {:ok, nil}
      {:error, error} -> {:error, error}
    end
  end

  def remove_topic(topic_id, opts) do
    scope = Keyword.fetch!(opts, :scope)

    with {:ok, graph} when not is_nil(graph) <- read_graph(scope),
         children <- prune_children(graph.children, topic_id) do
      persist_children(graph, children, scope)
    else
      {:ok, nil} -> {:ok, nil}
      {:error, error} -> {:error, error}
    end
  end

  def repair(graph, topics, opts) do
    scope = Keyword.fetch!(opts, :scope)
    children = normalize_children(topics, graph.children)

    persist_children(graph, children, scope)
  end

  def normalize_children(topics, children) do
    topic_ids = topics |> MapSet.new(& &1.id)

    Enum.reduce(children, %{}, fn {parent_id, child_ids}, normalized ->
      if MapSet.member?(topic_ids, parent_id) do
        child_ids =
          child_ids
          |> Enum.flat_map(&resolve_child_ids(&1, topic_ids, children, MapSet.new()))
          |> Enum.uniq()

        case child_ids do
          [] -> normalized
          child_ids -> Map.put(normalized, parent_id, child_ids)
        end
      else
        normalized
      end
    end)
  end

  def parent_candidates(topics, children, child_id) do
    topics
    |> Enum.filter(&is_nil(attachment_error(children, &1.id, child_id)))
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  def focus(nodes, topic_id) when topic_id in [nil, ""], do: nodes

  def focus(nodes, topic_id) do
    Enum.flat_map(nodes, &focus_node(&1, topic_id))
  end

  def tree(topics, children) do
    topics_by_id = Map.new(topics, &{&1.id, &1})

    child_ids =
      children
      |> Map.values()
      |> List.flatten()
      |> MapSet.new()

    tree =
      topics
      |> Enum.reject(&MapSet.member?(child_ids, &1.id))
      |> Enum.map(fn topic ->
        build_node(topic.id, nil, [], MapSet.new(), topics_by_id, children)
      end)
      |> sort_nodes()

    rendered_ids = tree |> collect_topic_ids() |> MapSet.new()
    topic_ids = topics |> Enum.map(& &1.id) |> MapSet.new()

    if rendered_ids == topic_ids do
      tree
    else
      raise ArgumentError, "topic graph contains a cycle or dangling topic reference"
    end
  end

  defp attach_child(children, parent_id, child_id) do
    case attachment_error(children, parent_id, child_id) do
      nil ->
        direct_children = Map.get(children, parent_id, [])
        {:ok, Map.put(children, parent_id, direct_children ++ [child_id])}

      :duplicate ->
        {:ok, children}

      error ->
        {:error, error}
    end
  end

  defp attachment_error(children, parent_id, child_id) do
    cond do
      parent_id == child_id -> :self_link
      child_id in Map.get(children, parent_id, []) -> :duplicate
      reachable?(children, child_id, parent_id, MapSet.new()) -> :cycle
      true -> nil
    end
  end

  defp detach_child(children, parent_id, child_id) do
    case Map.get(children, parent_id, []) |> Enum.reject(&(&1 == child_id)) do
      [] -> Map.delete(children, parent_id)
      child_ids -> Map.put(children, parent_id, child_ids)
    end
  end

  defp ensure_graph(scope) do
    case read_graph(scope) do
      {:ok, nil} -> create_graph(scope)
      result -> result
    end
  end

  defp create_graph(scope) do
    result =
      __MODULE__
      |> Ash.Changeset.for_create(:create, %{}, scope: scope)
      |> Ash.create()

    case result do
      {:ok, graph} ->
        {:ok, graph}

      {:error, error} ->
        case read_graph(scope) do
          {:ok, graph} when is_struct(graph, __MODULE__) -> {:ok, graph}
          _other -> {:error, error}
        end
    end
  end

  defp persist_children(graph, children, _scope) when children == graph.children do
    {:ok, graph}
  end

  defp persist_children(graph, children, scope) do
    graph
    |> Ash.Changeset.for_update(:update, %{}, scope: scope)
    |> Ash.Changeset.force_change_attribute(:children, children)
    |> Ash.update()
  end

  defp read_graph(scope) do
    __MODULE__
    |> Ash.read_one(scope: scope)
  end

  defp resolve_child_ids(topic_id, topic_ids, children, visited) do
    cond do
      MapSet.member?(topic_ids, topic_id) ->
        [topic_id]

      MapSet.member?(visited, topic_id) ->
        raise ArgumentError, "cycle detected in topic graph at #{topic_id}"

      true ->
        visited = MapSet.put(visited, topic_id)

        children
        |> Map.get(topic_id, [])
        |> Enum.flat_map(&resolve_child_ids(&1, topic_ids, children, visited))
    end
  end

  defp prune_children(children, topic_id) do
    children
    |> Map.delete(topic_id)
    |> Enum.reduce(%{}, fn {parent_id, child_ids}, result ->
      case Enum.reject(child_ids, &(&1 == topic_id)) do
        [] -> result
        remaining -> Map.put(result, parent_id, remaining)
      end
    end)
  end

  defp validate_topics(parent_id, child_id, scope) do
    topic_ids = Enum.uniq([parent_id, child_id])

    result =
      Topic
      |> Ash.Query.filter(id in ^topic_ids)
      |> Ash.read(scope: scope)

    case result do
      {:ok, topics} when length(topics) == length(topic_ids) -> :ok
      {:ok, _topics} -> {:error, :invalid_topics}
      {:error, error} -> {:error, error}
    end
  end

  defp reachable?(_children, node_id, node_id, _visited), do: true

  defp reachable?(children, node_id, target_id, visited) do
    if MapSet.member?(visited, node_id) do
      false
    else
      visited = MapSet.put(visited, node_id)

      children
      |> Map.get(node_id, [])
      |> Enum.any?(&reachable?(children, &1, target_id, visited))
    end
  end

  defp build_node(topic_id, parent_id, path, visited, topics, children) do
    if MapSet.member?(visited, topic_id) do
      raise ArgumentError, "cycle detected in topic graph at #{topic_id}"
    end

    topic = Map.fetch!(topics, topic_id)
    path = path ++ [topic_id]
    visited = MapSet.put(visited, topic_id)

    descendants =
      children
      |> Map.get(topic_id, [])
      |> Enum.map(&build_node(&1, topic_id, path, visited, topics, children))
      |> sort_nodes()

    %{
      children: descendants,
      dom_id: "topic-#{Enum.join(path, "-")}",
      parent_id: parent_id,
      path: path,
      topic: topic
    }
  end

  defp sort_nodes(nodes) do
    Enum.sort_by(nodes, &String.downcase(&1.topic.name))
  end

  defp focus_node(node, topic_id) do
    if node.topic.id == topic_id do
      [node]
    else
      case focus(node.children, topic_id) do
        [] -> []
        children -> [%{node | children: children}]
      end
    end
  end

  defp collect_topic_ids(nodes) do
    Enum.flat_map(nodes, fn node ->
      [node.topic.id | collect_topic_ids(node.children)]
    end)
  end
end
