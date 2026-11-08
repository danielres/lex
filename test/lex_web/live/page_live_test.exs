defmodule LexWeb.PageLiveTest do
  use LexWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Lex.Accounts
  alias Lex.Collaboration
  alias Lex.Wiki.Page
  alias Lex.Wiki.PageDocument
  alias Lex.Wiki.PageRevision
  alias Yex.Sync.SharedDoc

  setup :authenticate

  setup %{current_user: current_user} do
    {:ok, scope: create_scope("Test Space", current_user)}
  end

  test "a direct visit offers to create a missing page with a title", %{conn: conn, scope: scope} do
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/new-page")

    assert has_element?(view, "[data-testid='missing-page']", "This page doesn’t exist")
    assert has_element?(view, "[data-testid='page-creation-form']")
    assert has_element?(view, "[data-testid='page-creation-form'] input[value='New Page']")
    assert has_element?(view, "[data-testid='page-slug-preview']", "wiki/new-page")
    assert Ash.read!(Page, scope: scope) == []

    view
    |> form("[data-testid='page-creation-form']", page: %{title: "Different Page"})
    |> render_change()

    assert has_element?(view, "[data-testid='page-slug-preview']", "wiki/different-page")

    view
    |> form("[data-testid='page-creation-form']", page: %{title: ""})
    |> render_change()

    refute has_element?(view, "[data-testid='page-slug-preview']")

    view
    |> form("[data-testid='page-creation-form']", page: %{title: "No"})
    |> render_change()

    refute has_element?(view, "[data-testid='page-slug-preview']")

    view
    |> form("[data-testid='page-creation-form']", page: %{title: "A Better Title"})
    |> render_submit()

    assert_redirect(view, ~p"/test-space/wiki/a-better-title")
    assert [%{title: "A Better Title", slug: "a-better-title"}] = Ash.read!(Page, scope: scope)
  end

  test "members without page editing privileges can read but cannot edit or create pages", %{
    conn: conn,
    scope: scope
  } do
    page = scope |> Page.ensure!("Existing Page")
    member = create_user("Reader")
    {:ok, membership} = scope |> Accounts.invite_membership(member)
    member_scope = %{scope | current_membership: membership, current_user: member}
    {:ok, membership} = member_scope |> Accounts.accept_membership(membership, "Reader")
    {:ok, membership} = scope |> Accounts.set_membership_privileges(membership, [])
    member_scope = %{member_scope | current_membership: membership}
    conn = conn |> recycle() |> log_in_user(member)

    assert {:ok, fetched_page} = member_scope |> Page.fetch_by_slug(page.slug)
    assert fetched_page.id == page.id
    assert {:error, _error} = member_scope |> Page.ensure("Forbidden Page")
    assert {:error, _error} = Page.rename(page, "Forbidden Rename", scope: member_scope)

    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/#{page.slug}")

    refute has_element?(view, "button[phx-click='editing:toggle']")
    assert has_element?(view, "[phx-hook='LexicalEditor'][data-editable='false']")

    missing_conn = conn |> recycle() |> log_in_user(member)
    {:ok, missing_view, _html} = live(missing_conn, ~p"/test-space/wiki/missing-page")

    assert has_element?(missing_view, "[data-testid='missing-page']", "doesn’t exist")
    assert has_element?(missing_view, "[data-testid='missing-page']", "don’t have permission")
    refute has_element?(missing_view, "[data-testid='page-creation-form']")
  end

  test "preloads page references and creates missing link targets", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")
    scope |> Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home")

    assert has_element?(view, "[phx-hook=LexicalEditor][data-pages*='Summer Activities']")
    assert render(view) =~ "/test-space/wiki/summer-activities"

    render_hook(view, "page_repository:ensure", %{"title" => "Winter Plans"})

    assert Page.list!(scope: scope) |> Enum.any?(&(&1.title == "Winter Plans"))
  end

  test "opens a missing page when it is created by another viewer", %{conn: conn, scope: scope} do
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/new-page")

    assert has_element?(view, "[data-testid='missing-page']")

    page = scope |> Page.ensure!("New Page")

    assert has_element?(view, "[phx-hook='LexicalEditor'][data-document-id='#{page.id}']")
    refute has_element?(view, "[data-testid='missing-page']")
  end

  test "revisiting a slug reuses its page id", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Summer Activities")
    {:ok, _view, first_html} = live(conn, ~p"/test-space/wiki/summer-activities")
    [page] = Ash.read!(Page, scope: scope)

    second_conn = conn |> recycle() |> log_in_user(scope.current_user)
    {:ok, _view, second_html} = live(second_conn, ~p"/test-space/wiki/summer-activities")

    assert first_html =~ ~s(data-document-id="#{page.id}")
    assert second_html =~ ~s(data-document-id="#{page.id}")
    assert length(Ash.read!(Page, scope: scope)) == 1
  end

  test "different slugs use different collaboration document ids", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")
    scope |> Page.ensure!("Summer Activities")
    {:ok, _view, home_html} = live(conn, ~p"/test-space/wiki/home")
    summer_conn = conn |> recycle() |> log_in_user(scope.current_user)
    {:ok, _view, summer_html} = live(summer_conn, ~p"/test-space/wiki/summer-activities")

    [home, summer] = Page |> Ash.Query.sort(:slug) |> Ash.read!(scope: scope)

    assert home_html =~ ~s(data-document-id="#{home.id}")
    assert summer_html =~ ~s(data-document-id="#{summer.id}")
    refute home.id == summer.id
  end

  test "remains alive when a document is persisted", %{conn: conn, scope: scope} do
    page = scope |> Page.ensure!("Home")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home")

    assert :ok = scope |> Page.persist_document(page, "main", document("updated"))

    assert has_element?(view, "[phx-hook=LexicalEditor][data-document-id='#{page.id}']")
  end

  test "pushes updated content for embedded pages in the same space", %{
    conn: conn,
    scope: scope
  } do
    scope |> Page.ensure!("Home")
    embedded_page = scope |> Page.ensure!("Reusable Page")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home")
    snapshot = document_snapshot("main", "Reusable content")

    assert {:ok, :saved} =
             scope
             |> Page.save_document(
               embedded_page,
               "main",
               document("Reusable content"),
               %{
                 lexical_state: snapshot["lexical_state"],
                 search_text: snapshot["search_text"]
               }
             )

    page_id = embedded_page.id
    lexical_state = snapshot["lexical_state"]

    assert_push_event(view, "page_content_updated", %{
      content_hash: content_hash,
      lexical_state: ^lexical_state,
      page_id: ^page_id
    })

    assert is_binary(content_hash)
  end

  test "does not expose content updates from another space", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")
    other_scope = create_scope("Other Space", scope.current_user)
    other_page = other_scope |> Page.ensure!("Private Page")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home")
    snapshot = document_snapshot("main", "Private content")

    assert {:ok, :saved} =
             other_scope
             |> Page.save_document(
               other_page,
               "main",
               document("Private content"),
               %{
                 lexical_state: snapshot["lexical_state"],
                 search_text: snapshot["search_text"]
               }
             )

    refute_push_event(view, "page_content_updated", %{})
  end

  test "saves inline embeds as revisions of the referenced page", %{
    conn: conn,
    scope: scope
  } do
    containing_page = scope |> Page.ensure!("Home")
    embedded_page = scope |> Page.ensure!("Reusable Page")
    {:ok, shared_doc} = scope |> Collaboration.open_document("#{embedded_page.id}/main")
    :ok = SharedDoc.observe(shared_doc)
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home")

    render_hook(view, "page_repository:save", %{
      "documents" => [document_snapshot("main", "Embedded content")],
      "page_id" => embedded_page.id
    })

    assert [%{search_text: "Embedded content"}] = scope |> Page.list_revisions!(embedded_page)
    assert [] = scope |> Page.list_revisions!(containing_page)

    monitor = Process.monitor(shared_doc)
    :ok = Collaboration.close_document(shared_doc)
    assert_receive {:DOWN, ^monitor, :process, ^shared_doc, :normal}
  end

  test "the lock button toggles whether the editor is editable", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home")
    [page] = Ash.read!(Page, scope: scope)
    {:ok, shared_doc} = scope |> Collaboration.open_document("#{page.id}/main")
    :ok = SharedDoc.observe(shared_doc)

    assert has_element?(view, "[phx-hook=LexicalEditor][data-editable=false]")
    assert has_element?(view, "button[aria-label='Enable editing']")

    enable_editing(view)

    assert has_element?(view, "[phx-hook=LexicalEditor][data-editable=true]")
    assert has_element?(view, "button[aria-label='Make editor read-only']")
    refute has_element?(view, "[aria-label='Browse revisions']")

    view
    |> element("button[phx-click='editing:toggle']")
    |> render_click()

    assert_push_event(view, "page_save_requested", %{})
    assert has_element?(view, "[phx-hook=LexicalEditor][data-editable=false]")
    assert has_element?(view, "button[aria-label='Saving document'][disabled]")

    render_hook(view, "editing:save", %{
      "documents" => [document_snapshot("main", "Home content")]
    })

    assert_patch(view, ~p"/test-space/wiki/home")
    assert has_element?(view, "button[aria-label='Enable editing']")
    assert [page_document] = Ash.read!(PageDocument)
    assert page_document.search_text == "Home content"
    assert [revision] = Ash.read!(PageRevision)
    assert revision.lexical_state == document_snapshot("main", "Home content")["lexical_state"]
    assert revision.search_text == "Home content"

    monitor = Process.monitor(shared_doc)
    :ok = Collaboration.close_document(shared_doc)
    assert_receive {:DOWN, ^monitor, :process, ^shared_doc, :normal}
  end

  test "restores edit mode when saving fails", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home")

    enable_editing(view)

    view
    |> element("button[phx-click='editing:toggle']")
    |> render_click()

    assert_push_event(view, "page_save_requested", %{})

    render_hook(view, "editing:save", %{"error" => "snapshot_failed"})

    assert has_element?(view, "[phx-hook=LexicalEditor][data-editable=true]")
    assert has_element?(view, "button[aria-label='Make editor read-only']")
    assert render(view) =~ "Could not save the document"
  end

  test "renames a page while remaining in edit mode", %{conn: conn, scope: scope} do
    page = scope |> Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/summer-activities")

    enable_editing(view)

    assert has_element?(view, "#page-title-form input[value='Summer Activities']")

    view
    |> form("#page-title-form", page_title: %{title: "Winter Activities"})
    |> render_submit()

    assert_push_event(view, "page_title_blur", %{})
    refute_patched(view)
    assert Page.get!(page.id, scope: scope).title == "Winter Activities"
    assert Page.get!(page.id, scope: scope).slug == "winter-activities"
    assert has_element?(view, "#page-title-form input[value='Winter Activities']")
  end

  test "propagates a rename to other viewers of the same page", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Summer Activities")
    {:ok, first_view, _html} = live(conn, ~p"/test-space/wiki/summer-activities")
    second_conn = conn |> recycle() |> log_in_user(scope.current_user)
    {:ok, second_view, _html} = live(second_conn, ~p"/test-space/wiki/summer-activities")

    enable_editing(first_view)

    first_view
    |> form("#page-title-form", page_title: %{title: "Winter Activities"})
    |> render_submit()

    assert_patch(second_view, ~p"/test-space/wiki/winter-activities")
    assert has_element?(second_view, "h1", "Winter Activities")
  end

  test "refreshes page references when another page is renamed", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")
    summer = scope |> Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home")

    Page.rename!(summer, "Winter Activities", scope: scope)

    assert has_element?(view, "[phx-hook=LexicalEditor][data-pages*='Winter Activities']")
    refute has_element?(view, "[phx-hook=LexicalEditor][data-pages*='Summer Activities']")
  end

  test "refreshes page references when another page is created", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home")

    scope |> Page.ensure!("Summer Activities")

    assert has_element?(view, "[phx-hook=LexicalEditor][data-pages*='Summer Activities']")
  end

  test "resets an unsaved page title", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/summer-activities")

    enable_editing(view)

    view
    |> form("#page-title-form", page_title: %{title: "Unsaved Title"})
    |> render_change()

    view
    |> element("button[aria-label='Cancel title change']")
    |> render_click()

    assert has_element?(view, "#page-title-form input[value='Summer Activities']")
  end

  test "resets an unsaved page title when the input loses focus", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/summer-activities")

    enable_editing(view)

    view
    |> form("#page-title-form", page_title: %{title: "Unsaved Title"})
    |> render_change()

    view
    |> element("#page_title_title")
    |> render_blur()

    assert has_element?(view, "#page-title-form input[value='Summer Activities']")
  end

  test "resets an unsaved page title with Escape", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/summer-activities")

    enable_editing(view)

    view
    |> form("#page-title-form", page_title: %{title: "Unsaved Title"})
    |> render_change()

    view
    |> element("#page_title_title")
    |> render_keydown(%{"key" => "Escape"})

    assert has_element?(view, "#page-title-form input[value='Summer Activities']")
  end

  test "shows title errors without renaming the page", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Winter Activities")
    page = scope |> Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/summer-activities")

    enable_editing(view)

    view
    |> form("#page-title-form", page_title: %{title: "Winter Activities"})
    |> render_submit()

    assert render(view) =~ "Not available"
    assert Page.get!(page.id, scope: scope).title == "Summer Activities"
  end

  test "does not offer title editing for the home page", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home")

    enable_editing(view)

    refute has_element?(view, "#page-title-form")
  end

  test "browses revisions with URL-backed previous and next navigation", %{
    conn: conn,
    scope: scope
  } do
    page = scope |> Page.ensure!("Home")
    first_revision = scope |> create_revision(page, "First version")
    second_revision = scope |> create_revision(page, "Second version")

    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home/revisions")

    assert has_element?(view, "#revision-preview-#{second_revision.id}")
    assert render(view) =~ "First version"
    refute has_element?(view, "[aria-label='Enable editing']")
    assert has_element?(view, "a#previous-revision")
    assert has_element?(view, "button#next-revision[disabled]")

    view
    |> element("a#previous-revision")
    |> render_click()

    assert_patch(view, ~p"/test-space/wiki/home/revisions/#{first_revision.id}")
    assert has_element?(view, "#revision-preview-#{first_revision.id}")

    assert has_element?(
             view,
             "#revision-preview-#{first_revision.id}[data-previous-lexical-state='null']"
           )

    assert has_element?(view, "button#previous-revision[disabled]")
    assert has_element?(view, "a#next-revision")
    assert has_element?(view, "#current-page-editor.hidden #lexical-editor-#{page.id}")
  end

  test "shows an empty history before the first revision", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home/revisions")

    assert render(view) =~ "No revisions yet"
    refute has_element?(view, "button[aria-label='Restore revision']")
  end

  test "passes the authenticated user to revision previews", %{conn: conn, scope: scope} do
    page = scope |> Page.ensure!("Home")
    revision = scope |> create_revision(page, "First version")

    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home/revisions")

    assert has_element?(
             view,
             "#revision-preview-#{revision.id}[data-collaborator-display-name][data-collaborator-hue]"
           )
  end

  test "shows who contributed to a revision", %{conn: conn, scope: scope} do
    page = scope |> Page.ensure!("Home")
    contributor = create_user("Revision Contributor")
    _revision = scope |> create_revision(page, "First version", [contributor.id])

    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home/revisions")

    assert has_element?(
             view,
             "[data-testid='revision-contributors']",
             "Revision Contributor"
           )
  end

  test "does not open another page's revision", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")
    other_page = scope |> Page.ensure!("Other Page")
    revision = scope |> create_revision(other_page, "Other content")

    assert_raise Ash.Error.Query.NotFound, fn ->
      live(conn, ~p"/test-space/wiki/home/revisions/#{revision.id}")
    end
  end

  test "preserves the current document before restoring a revision", %{
    conn: conn,
    scope: scope
  } do
    page = scope |> Page.ensure!("Home")
    source_revision = scope |> create_revision(page, "First version")
    _current_revision = scope |> create_revision(page, "Current version")
    {:ok, shared_doc} = scope |> Collaboration.open_document("#{page.id}/main")
    :ok = SharedDoc.observe(shared_doc)

    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home/revisions/#{source_revision.id}")

    view
    |> element("button[aria-label='Restore revision']")
    |> render_click()

    lexical_state = source_revision.lexical_state
    revision_id = source_revision.id

    assert_push_event(view, "revision_restore_requested", %{
      lexical_state: ^lexical_state,
      revision_id: ^revision_id
    })

    render_hook(view, "revisions:preserve", %{
      "documents" => [document_snapshot("main", "Unsaved collaborative edits")]
    })

    [preserved_revision | _revisions] = scope |> Page.list_revisions!(page)
    assert preserved_revision.restored_from_revision_id == nil
    assert preserved_revision.search_text == "Unsaved collaborative edits"

    render_hook(view, "revisions:commit_restore", %{
      "documents" => [document_snapshot("main", "First version restored")],
      "revision_id" => source_revision.id
    })

    assert_patch(view, ~p"/test-space/wiki/home")

    [restored_revision, preserved_revision_after_restore | _revisions] =
      scope |> Page.list_revisions!(page)

    assert restored_revision.restored_from_revision_id == source_revision.id
    assert restored_revision.search_text == "First version restored"
    assert preserved_revision_after_restore.id == preserved_revision.id

    monitor = Process.monitor(shared_doc)
    :ok = Collaboration.close_document(shared_doc)
    assert_receive {:DOWN, ^monitor, :process, ^shared_doc, :normal}
  end

  test "invalid slugs return not found and do not create pages", %{conn: conn, scope: scope} do
    error =
      assert_raise Ash.Error.Query.NotFound, fn ->
        get(conn, "/test-space/wiki/Summer-Activities")
      end

    assert Plug.Exception.status(error) == 404
    assert Ash.read!(Page, scope: scope) == []
  end

  defp document(text) do
    doc = Yex.Doc.new()
    doc |> Yex.Doc.get_text("content") |> Yex.Text.insert(0, text)
    doc
  end

  defp enable_editing(view) do
    view
    |> element("button[phx-click='editing:toggle']")
    |> render_click()

    refute_patched(view)
  end

  defp document_snapshot(document_key, text) do
    %{
      "document_key" => document_key,
      "lexical_state" => %{
        "root" => %{
          "children" => [],
          "text" => text,
          "type" => "root",
          "version" => 1
        }
      },
      "search_text" => text
    }
  end

  defp create_revision(scope, page, text, contributor_ids \\ []) do
    assert {:ok, :saved} =
             scope
             |> Page.record_revision(
               page,
               %{
                 contributor_ids: contributor_ids,
                 lexical_state: document_snapshot("main", text)["lexical_state"],
                 search_text: text
               },
               nil
             )

    scope |> Page.list_revisions!(page) |> List.first()
  end
end
