defmodule Lex.Topics.GraphTest do
  use Lex.DataCase

  alias Lex.Accounts.Membership
  alias Lex.Scope
  alias Lex.Topics.Graph
  alias Lex.Topics.Topic

  setup do
    owner_scope = create_scope("Topics Space", create_user("Topics Owner"))
    second_scope = create_scope("Second Space", create_user("Second Owner"))

    {:ok, owner_scope: owner_scope, second_scope: second_scope}
  end

  test "graph access requires an active membership", %{owner_scope: owner_scope} do
    assert {:ok, root} = owner_scope |> create_topic("Root Topic")
    assert {:ok, child} = owner_scope |> create_topic("Child Topic")
    invited_scope = owner_scope |> invite_member("Invited Member")

    assert {:error, _error} = Graph.attach(root.id, child.id, scope: invited_scope)

    member_scope = invited_scope |> activate_member()

    assert {:ok, _graph} = Graph.attach(root.id, child.id, scope: member_scope)

    assert {:ok, membership} = owner_scope |> Membership.disable(member_scope.membership)
    disabled_scope = %{member_scope | membership: membership}

    assert {:ok, nil} = Graph.detach(root.id, child.id, scope: disabled_scope)

    assert {:ok, graph} = Ash.read_one(Graph, scope: owner_scope)
    assert graph.children == %{root.id => [child.id]}
  end

  test "graph rejects invalid relationships", %{
    owner_scope: owner_scope,
    second_scope: second_scope
  } do
    assert {:ok, root} = owner_scope |> create_topic("Root Topic")
    assert {:ok, child} = owner_scope |> create_topic("Child Topic")
    assert {:ok, foreign_topic} = second_scope |> create_topic("Foreign Topic")

    assert {:ok, graph} = Graph.attach(root.id, child.id, scope: owner_scope)
    assert graph.children == %{root.id => [child.id]}

    assert {:ok, unchanged_graph} = Graph.attach(root.id, child.id, scope: owner_scope)
    assert unchanged_graph.children == graph.children

    assert {:error, :self_link} = Graph.attach(root.id, root.id, scope: owner_scope)

    assert {:error, :invalid_topics} =
             Graph.attach(root.id, foreign_topic.id, scope: owner_scope)

    assert {:error, :cycle} = Graph.attach(child.id, root.id, scope: owner_scope)

    assert {:ok, detached_graph} = Graph.detach(root.id, child.id, scope: owner_scope)
    assert detached_graph.children == %{}
  end

  test "topic deletion keeps pruning graph references", %{owner_scope: owner_scope} do
    assert {:ok, root} = owner_scope |> create_topic("Root Topic")
    assert {:ok, middle} = owner_scope |> create_topic("Middle Topic")
    assert {:ok, child} = owner_scope |> create_topic("Child Topic")

    assert {:ok, _graph} = Graph.attach(root.id, middle.id, scope: owner_scope)
    assert {:ok, _graph} = Graph.attach(middle.id, child.id, scope: owner_scope)
    assert :ok = Ash.destroy(middle, scope: owner_scope)

    graph = Graph |> Ash.read_one!(scope: owner_scope)

    assert graph.children == %{}
  end

  test "repair persists normalized children once", %{owner_scope: owner_scope} do
    assert {:ok, root} = owner_scope |> create_topic("Root Topic")
    assert {:ok, child} = owner_scope |> create_topic("Child Topic")
    assert {:ok, graph} = Graph.attach(root.id, child.id, scope: owner_scope)

    missing_topic_id = Ash.UUID.generate()
    dangling_children = %{root.id => [missing_topic_id], missing_topic_id => [child.id]}

    assert {:ok, graph} =
             graph
             |> Ash.Changeset.for_update(:update, %{}, scope: owner_scope)
             |> Ash.Changeset.force_change_attribute(:children, dangling_children)
             |> Ash.update()

    assert {:ok, repaired_graph} =
             Graph.repair(graph, [root, child], scope: owner_scope)

    assert repaired_graph.children == %{root.id => [child.id]}
    assert repaired_graph.version == graph.version + 1

    assert {:ok, unchanged_graph} =
             Graph.repair(repaired_graph, [root, child], scope: owner_scope)

    assert unchanged_graph.version == repaired_graph.version

    persisted_graph = Graph |> Ash.read_one!(scope: owner_scope)

    assert persisted_graph.children == repaired_graph.children
    assert persisted_graph.version == repaired_graph.version
  end

  defp create_topic(scope, name) do
    Topic
    |> Ash.Changeset.for_create(:create, %{name: name}, scope: scope)
    |> Ash.create()
  end

  defp invite_member(scope, display_name) do
    user = create_user(display_name)
    {:ok, membership} = scope |> Membership.invite(user.id)

    %Scope{
      membership: membership,
      space: scope.space,
      user: user
    }
  end

  defp activate_member(scope) do
    {:ok, membership} =
      scope |> Membership.accept(scope.membership, scope.user.display_name)

    %{scope | membership: membership}
  end
end
