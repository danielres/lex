defmodule Lex.Topics.TopicTest do
  use Lex.DataCase

  alias Lex.Accounts.Membership
  alias Lex.Scope
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

  test "topics support Unicode names", %{owner_scope: owner_scope} do
    assert {:ok, topic} = owner_scope |> create_topic("東京")
    assert topic.slug == "東京"
  end

  test "topic access requires an active membership", %{owner_scope: owner_scope} do
    invited_scope = owner_scope |> invite_member("Invited Member")

    assert {:ok, []} = Ash.read(Topic, scope: invited_scope)
    assert {:error, _error} = invited_scope |> create_topic("Invited Topic")

    member_scope = invited_scope |> activate_member()

    assert {:ok, member_topic} = member_scope |> create_topic("Member Topic")

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
