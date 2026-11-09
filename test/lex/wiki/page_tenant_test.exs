defmodule Lex.Wiki.PageTenantTest do
  use Lex.DataCase

  alias Lex.Wiki.Page
  alias Lex.Wiki.PageDocument
  alias Lex.Wiki.PageRevision
  alias Lex.Wiki.PageRevisionContributor

  setup do
    first_scope = create_scope("First Space", create_user("First Owner"))
    second_scope = create_scope("Second Space", create_user("Second Owner"))
    page = first_scope |> Page.ensure!("Tenant Boundary")

    {:ok, first_scope: first_scope, page: page, second_scope: second_scope}
  end

  test "page documents stay within their parent page's space", context do
    %{first_scope: first_scope, page: page, second_scope: second_scope} = context

    document =
      PageDocument
      |> Ash.Changeset.for_create(
        :persist,
        %{document_key: "main", page_id: page.id, yjs_state: <<0, 0>>},
        scope: first_scope
      )
      |> Ash.create!()

    assert {:ok, nil} =
             Ash.get(PageDocument, document.id,
               not_found_error?: false,
               scope: second_scope
             )

    assert {:error, error} =
             PageDocument
             |> Ash.Changeset.for_create(
               :persist,
               %{document_key: "foreign", page_id: page.id, yjs_state: <<0, 0>>},
               scope: second_scope
             )
             |> Ash.create()

    assert Exception.message(error) =~ "does not belong to this space"
  end

  test "page revisions stay within their parent page's space", context do
    %{first_scope: first_scope, page: page, second_scope: second_scope} = context
    {:ok, revision} = create_revision(first_scope, page.id)

    assert {:ok, nil} =
             Ash.get(PageRevision, revision.id,
               not_found_error?: false,
               scope: second_scope
             )

    assert {:error, error} = create_revision(second_scope, page.id)
    assert Exception.message(error) =~ "does not belong to this space"
  end

  test "revision contributors stay within their revision's space", context do
    %{first_scope: first_scope, page: page, second_scope: second_scope} = context
    {:ok, revision} = create_revision(first_scope, page.id)

    contributor =
      PageRevisionContributor
      |> Ash.Changeset.for_create(
        :create,
        %{page_revision_id: revision.id, user_id: first_scope.user.id},
        scope: first_scope
      )
      |> Ash.create!()

    assert {:ok, nil} =
             Ash.get(
               PageRevisionContributor,
               %{page_revision_id: contributor.page_revision_id, user_id: contributor.user_id},
               not_found_error?: false,
               scope: second_scope
             )

    assert {:error, error} =
             PageRevisionContributor
             |> Ash.Changeset.for_create(
               :create,
               %{page_revision_id: revision.id, user_id: second_scope.user.id},
               scope: second_scope
             )
             |> Ash.create()

    assert Exception.message(error) =~ "does not belong to this space"
  end

  defp create_revision(scope, page_id) do
    PageRevision
    |> Ash.Changeset.for_create(
      :create,
      %{
        content_hash: String.duplicate("a", 64),
        lexical_state: %{},
        page_id: page_id,
        search_text: ""
      },
      scope: scope
    )
    |> Ash.create()
  end
end
