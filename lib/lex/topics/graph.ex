defmodule Lex.Topics.Graph do
  alias Lex.Accounts
  alias Lex.Accounts.Membership.Checks.ActiveMember
  alias Lex.Topics.Graph.{Topology, Tree}
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
         {:ok, children} <- Topology.attach(graph.children, parent_id, child_id) do
      persist_children(graph, children, scope)
    end
  end

  def move(source_parent_id, parent_id, child_id, opts) do
    scope = Keyword.fetch!(opts, :scope)

    with :ok <- validate_topics(parent_id, child_id, scope),
         {:ok, graph} when not is_nil(graph) <- read_graph(scope),
         {:ok, children} <- Topology.move(graph.children, source_parent_id, parent_id, child_id) do
      persist_children(graph, children, scope)
    else
      {:ok, nil} -> {:error, :stale_parent}
      {:error, error} -> {:error, error}
    end
  end

  def detach(parent_id, child_id, opts) do
    scope = Keyword.fetch!(opts, :scope)

    with {:ok, graph} when not is_nil(graph) <- read_graph(scope),
         children <- Topology.detach(graph.children, parent_id, child_id) do
      persist_children(graph, children, scope)
    else
      {:ok, nil} -> {:ok, nil}
      {:error, error} -> {:error, error}
    end
  end

  def remove_topic(topic_id, opts) do
    scope = Keyword.fetch!(opts, :scope)

    with {:ok, graph} when not is_nil(graph) <- read_graph(scope),
         children <- Topology.remove_topic(graph.children, topic_id) do
      persist_children(graph, children, scope)
    else
      {:ok, nil} -> {:ok, nil}
      {:error, error} -> {:error, error}
    end
  end

  def repair(graph, topics, opts) do
    scope = Keyword.fetch!(opts, :scope)
    children = Topology.normalize_children(topics, graph.children)

    persist_children(graph, children, scope)
  end

  defdelegate focus(nodes, topic_id), to: Tree
  defdelegate normalize_children(topics, children), to: Topology
  defdelegate parent_candidates(topics, children, child_id), to: Topology

  def tree(topics, children), do: Tree.build(topics, children)

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
end
