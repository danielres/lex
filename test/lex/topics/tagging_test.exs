defmodule Lex.Topics.TaggingTest do
  use Lex.DataCase

  alias Lex.Accounts.Membership
  alias Lex.Scope
  alias Lex.Topics.Tagging
  alias Lex.Topics.Topic

  setup do
    owner_scope = create_scope("Topics Space", create_user("Topics Owner"))
    second_scope = create_scope("Second Space", create_user("Second Owner"))

    {:ok, owner_scope: owner_scope, second_scope: second_scope}
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
