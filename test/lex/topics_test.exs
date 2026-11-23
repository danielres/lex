defmodule Lex.TopicsTest do
  use Lex.DataCase

  alias Lex.Accounts.Membership
  alias Lex.Scope
  alias Lex.Topics.Graph
  alias Lex.Topics.Tagging
  alias Lex.Topics.Topic

  setup do
    owner_scope = create_scope("Topics Space", create_user("Topics Owner"))
    second_scope = create_scope("Second Space", create_user("Second Owner"))

    {:ok, owner_scope: owner_scope, second_scope: second_scope}
  end

  test "topics are isolated by space and record their author", %{
    owner_scope: owner_scope,
    second_scope: second_scope
  } do
    assert {:ok, first_topic} = owner_scope |> create_topic("Shared Topic")
    assert {:ok, second_topic} = second_scope |> create_topic("Shared Topic")

    assert first_topic.author_id == owner_scope.user.id
    assert first_topic.space_id == owner_scope.space.id
    assert second_topic.author_id == second_scope.user.id
    assert second_topic.space_id == second_scope.space.id

    assert [listed_topic] = Ash.read!(Topic, scope: owner_scope)
    assert listed_topic.id == first_topic.id

    assert [listed_topic] = Ash.read!(Topic, scope: second_scope)
    assert listed_topic.id == second_topic.id

    assert {:ok, nil} =
             Ash.get(Topic, first_topic.id,
               not_found_error?: false,
               scope: second_scope
             )
  end

  test "topics reject names that cannot produce a slug", %{owner_scope: owner_scope} do
    assert {:error, error} = owner_scope |> create_topic("東京")

    assert Exception.message(error) =~
             "must contain at least one Latin letter (a-z) or number"
  end

  test "topic and graph access requires an active membership", %{owner_scope: owner_scope} do
    assert {:ok, root} = owner_scope |> create_topic("Root Topic")
    assert {:ok, child} = owner_scope |> create_topic("Child Topic")
    invited_scope = owner_scope |> invite_member("Invited Member")

    assert {:ok, []} = Ash.read(Topic, scope: invited_scope)
    assert {:error, _error} = invited_scope |> create_topic("Invited Topic")
    assert {:error, _error} = Graph.attach(root.id, child.id, scope: invited_scope)

    member_scope = invited_scope |> activate_member()

    assert {:ok, member_topic} = member_scope |> create_topic("Member Topic")
    assert {:ok, _graph} = Graph.attach(root.id, child.id, scope: member_scope)

    assert {:ok, membership} = owner_scope |> Membership.disable(member_scope.membership)
    disabled_scope = %{member_scope | membership: membership}

    assert {:ok, []} = Ash.read(Topic, scope: disabled_scope)
    assert {:error, _error} = disabled_scope |> create_topic("Disabled Topic")

    assert {:error, _error} =
             member_topic
             |> Ash.Changeset.for_update(
               :update,
               %{name: "Blocked Rename"},
               scope: disabled_scope
             )
             |> Ash.update()

    assert {:error, _error} = Ash.destroy(member_topic, scope: disabled_scope)
    assert {:ok, nil} = Graph.detach(root.id, child.id, scope: disabled_scope)

    assert {:ok, graph} = Ash.read_one(Graph, scope: owner_scope)
    assert graph.children == %{root.id => [child.id]}
  end

  test "only a topic author or the space owner can destroy it", %{owner_scope: owner_scope} do
    author_scope = owner_scope |> add_member("Topic Author")
    other_scope = owner_scope |> add_member("Other Member")

    assert {:ok, author_topic} = author_scope |> create_topic("Author Topic")
    assert {:error, _error} = Ash.destroy(author_topic, scope: other_scope)
    assert :ok = Ash.destroy(author_topic, scope: author_scope)

    assert {:ok, owner_deleted_topic} = author_scope |> create_topic("Owner Deleted")
    assert :ok = Ash.destroy(owner_deleted_topic, scope: owner_scope)
  end

  test "topic graph rejects invalid relationships", %{
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

  test "topic graph repair persists normalized children once", %{owner_scope: owner_scope} do
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

  test "taggings enforce their author, target, and space boundaries", %{
    owner_scope: owner_scope,
    second_scope: second_scope
  } do
    target_scope = owner_scope |> add_member("Tagged Member")
    endorser_scope = owner_scope |> add_member("Endorser")
    other_member_scope = owner_scope |> add_member("Other Member")
    foreign_target_scope = second_scope |> add_member("Foreign Target")

    assert {:ok, topic} = owner_scope |> create_topic("Elixir")
    assert {:ok, foreign_topic} = second_scope |> create_topic("Foreign Topic")

    assert {:ok, tagging} =
             Tagging.set(
               target_scope.membership,
               topic,
               endorser_scope.membership,
               %{dimensions: %{}, text: "Recommended"},
               scope: endorser_scope
             )

    assert {:error, _error} =
             Tagging.set(
               target_scope.membership,
               topic,
               endorser_scope.membership,
               %{dimensions: %{}, text: "Changed"},
               scope: other_member_scope
             )

    assert {:error, _error} = Tagging.remove(tagging, scope: other_member_scope)

    assert {:error, _error} =
             Tagging.set(
               target_scope.membership,
               foreign_topic,
               endorser_scope.membership,
               %{dimensions: %{}, text: "Cross-space topic"},
               scope: endorser_scope
             )

    assert {:error, _error} =
             Tagging.set(
               foreign_target_scope.membership,
               topic,
               endorser_scope.membership,
               %{dimensions: %{}, text: "Cross-space target"},
               scope: endorser_scope
             )

    assert {:ok, membership} =
             owner_scope |> Membership.disable(endorser_scope.membership)

    disabled_endorser_scope = %{endorser_scope | membership: membership}

    assert {:ok, []} =
             Tagging.for_target(target_scope.membership, scope: disabled_endorser_scope)

    assert {:error, _error} =
             Tagging.set(
               target_scope.membership,
               topic,
               membership,
               %{dimensions: %{}, text: "Disabled endorsement"},
               scope: disabled_endorser_scope
             )

    assert {:ok, removed_tagging} = Tagging.remove(tagging, scope: target_scope)
    assert removed_tagging.id == tagging.id
  end

  test "self-assessments retain notes without ratings", %{owner_scope: owner_scope} do
    assert {:ok, topic} = owner_scope |> create_topic("Documentation")

    assert {:ok, tagging} =
             Tagging.set(
               owner_scope.membership,
               topic,
               owner_scope.membership,
               %{dimensions: %{}, text: "Enjoys writing guides"},
               scope: owner_scope
             )

    assert tagging.dimensions == %{}
    assert tagging.text == "Enjoys writing guides"

    assert {:ok, nil} =
             Tagging.set(
               owner_scope.membership,
               topic,
               owner_scope.membership,
               %{dimensions: %{}, text: ""},
               scope: owner_scope
             )
  end

  test "taggings reject unsupported target types", %{owner_scope: owner_scope} do
    assert {:ok, topic} = owner_scope |> create_topic("Elixir")

    assert {:error, _error} =
             Tagging
             |> Ash.Changeset.for_create(
               :create,
               %{
                 dimensions: %{},
                 taggable_id: owner_scope.membership.id,
                 taggable_type: "page",
                 tagged_by_membership_id: owner_scope.membership.id,
                 text: "Unsupported target",
                 topic_id: topic.id
               },
               scope: owner_scope
             )
             |> Ash.create()
  end

  test "taggings validate dimensions on creates and updates", %{owner_scope: owner_scope} do
    assert {:ok, topic} = owner_scope |> create_topic("Phoenix")

    assert {:error, _error} =
             Tagging.set(
               owner_scope.membership,
               topic,
               owner_scope.membership,
               %{dimensions: %{"unknown" => 5}, text: nil},
               scope: owner_scope
             )

    assert {:ok, tagging} =
             Tagging.set(
               owner_scope.membership,
               topic,
               owner_scope.membership,
               %{dimensions: %{"interest" => 5}, text: nil},
               scope: owner_scope
             )

    assert {:error, _error} =
             Tagging.set(
               owner_scope.membership,
               topic,
               owner_scope.membership,
               %{dimensions: %{"interest" => 11}, text: nil},
               scope: owner_scope
             )

    assert {:ok, persisted_tagging} =
             Tagging.get(
               owner_scope.membership,
               topic,
               owner_scope.membership,
               scope: owner_scope
             )

    assert persisted_tagging.id == tagging.id
    assert persisted_tagging.dimensions == %{"interest" => 5}
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

  defp add_member(scope, display_name) do
    scope
    |> invite_member(display_name)
    |> activate_member()
  end
end
