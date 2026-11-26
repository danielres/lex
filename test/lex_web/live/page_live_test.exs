defmodule LexWeb.PageLiveTest do
  use LexWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Lex.Accounts.Membership
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

  test "redirects a noncanonical page URL to its canonical slug", %{conn: conn} do
    path = ~p"/test-space/wiki/#{"Été à l'assemblée"}"
    canonical_path = ~p"/test-space/wiki/été-à-l-assemblée"

    result = live(conn, path)
    assert {:error, {:live_redirect, %{to: ^canonical_path}}} = result

    assert {:ok, view, _html} = follow_redirect(result, conn, canonical_path)
    assert has_element?(view, "[data-testid='missing-page']")

    assert has_element?(
             view,
             "[data-testid='page-creation-form'] input[value=\"Été à l'assemblée\"]"
           )
  end

  test "preserves revision routes when canonicalizing a page URL", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")

    revisions_path = ~p"/test-space/wiki/Home/revisions"
    canonical_revisions_path = ~p"/test-space/wiki/home/revisions"

    assert {:error, {:live_redirect, %{to: ^canonical_revisions_path}}} =
             live(conn, revisions_path)

    revision_path = ~p"/test-space/wiki/Home/revisions/3"
    canonical_revision_path = ~p"/test-space/wiki/home/revisions/3"

    assert {:error, {:live_redirect, %{to: ^canonical_revision_path}}} =
             live(conn, revision_path)
  end

  test "revision routes require an existing page", %{conn: conn, scope: scope} do
    canonical_error =
      assert_raise Ash.Error.Query.NotFound, fn ->
        get(conn, "/test-space/wiki/missing/revisions")
      end

    noncanonical_error =
      assert_raise Ash.Error.Query.NotFound, fn ->
        get(conn, "/test-space/wiki/Missing/revisions")
      end

    assert Plug.Exception.status(canonical_error) == 404
    assert Plug.Exception.status(noncanonical_error) == 404
    assert Ash.read!(Page, scope: scope) == []
  end

  test "members without page editing privileges can read but cannot edit or create pages", %{
    conn: conn,
    scope: scope
  } do
    page = scope |> Page.ensure!("Existing Page")
    member = create_user("Reader")
    member_scope = scope |> add_member(member, "Reader")
    {:ok, membership} = scope |> Membership.set_privileges(member_scope.membership, [])
    member_scope = %{member_scope | membership: membership}
    conn = conn |> recycle() |> log_in_user(member)

    assert {:ok, fetched_page} = member_scope |> Page.fetch_by_slug(page.slug)
    assert fetched_page.id == page.id
    assert {:error, _error} = member_scope |> Page.ensure("Forbidden Page")
    assert {:error, _error} = Page.rename(page, "Forbidden Rename", scope: member_scope)

    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/#{page.slug}")

    refute has_element?(view, "[data-testid='editing-toggle']")
    assert has_element?(view, "[data-testid='page-editor'][data-editable='false']")

    view
    |> element("[data-testid='page-info-toggle']")
    |> render_click()

    refute has_element?(view, "[data-testid='edit-title-button']")

    render_hook(view, "edit_title:change", %{
      "page_title" => %{"title" => "Forbidden Rename"}
    })

    render_hook(view, "edit_title:save", %{
      "page_title" => %{"title" => "Forbidden Rename"}
    })

    assert Page.get!(page.id, scope: member_scope).title == "Existing Page"

    missing_conn = conn |> recycle() |> log_in_user(member)
    {:ok, missing_view, _html} = live(missing_conn, ~p"/test-space/wiki/missing-page")

    assert has_element?(missing_view, "[data-testid='missing-page']", "doesn’t exist")
    assert has_element?(missing_view, "[data-testid='missing-page']", "don’t have permission")
    refute has_element?(missing_view, "[data-testid='page-creation-form']")
  end

  test "removes a disabled member from a connected page", %{conn: conn, scope: scope} do
    page = scope |> Page.ensure!("Home")
    member = create_user("Connected Member")
    member_scope = scope |> add_member(member, "Connected Member")
    conn = conn |> recycle() |> log_in_user(member)

    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home")

    assert has_element?(view, "[data-testid='page-editor'][data-document-id='#{page.id}']")
    view_pid = view.pid
    monitor = Process.monitor(view_pid)

    assert {:ok, _membership} = scope |> Membership.disable(member_scope.membership)
    assert_redirect(view, ~p"/")
    assert_receive {:DOWN, ^monitor, :process, ^view_pid, _reason}
  end

  test "refreshes privileges for a connected member", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")
    member = create_user("Connected Editor")
    member_scope = scope |> add_member(member, "Connected Editor")
    conn = conn |> recycle() |> log_in_user(member)

    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home")

    enable_editing(view)
    assert has_element?(view, "[data-testid='page-editor'][data-editable='true']")

    assert {:ok, _membership} =
             scope |> Membership.set_privileges(member_scope.membership, [])

    refute has_element?(view, "[data-testid='editing-toggle']")
    assert has_element?(view, "[data-testid='page-editor'][data-editable='false']")
  end

  test "preloads page references and creates missing link targets", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")
    scope |> Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home")

    assert has_element?(view, "[data-testid='page-editor'][data-pages*='Summer Activities']")
    assert render(view) =~ "/test-space/wiki/summer-activities"

    render_hook(view, "page_repository:ensure", %{"title" => "Winter Plans"})

    assert Page.list!(scope: scope) |> Enum.any?(&(&1.title == "Winter Plans"))
  end

  test "opens a missing page when it is created by another viewer", %{conn: conn, scope: scope} do
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/new-page")

    assert has_element?(view, "[data-testid='missing-page']")

    page = scope |> Page.ensure!("New Page")

    assert has_element?(view, "[data-testid='page-editor'][data-document-id='#{page.id}']")
    refute has_element?(view, "[data-testid='missing-page']")
  end

  test "revisiting a slug reuses its page id", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Summer Activities")
    {:ok, _view, first_html} = live(conn, ~p"/test-space/wiki/summer-activities")
    [page] = Ash.read!(Page, scope: scope)

    second_conn = conn |> recycle() |> log_in_user(scope.user)
    {:ok, _view, second_html} = live(second_conn, ~p"/test-space/wiki/summer-activities")

    assert first_html =~ ~s(data-document-id="#{page.id}")
    assert second_html =~ ~s(data-document-id="#{page.id}")
    assert length(Ash.read!(Page, scope: scope)) == 1
  end

  test "different slugs use different collaboration document ids", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")
    scope |> Page.ensure!("Summer Activities")
    {:ok, _view, home_html} = live(conn, ~p"/test-space/wiki/home")
    summer_conn = conn |> recycle() |> log_in_user(scope.user)
    {:ok, _view, summer_html} = live(summer_conn, ~p"/test-space/wiki/summer-activities")

    [home, summer] = Page |> Ash.Query.sort(:slug) |> Ash.read!(scope: scope)

    assert home_html =~ ~s(data-document-id="#{home.id}")
    assert summer_html =~ ~s(data-document-id="#{summer.id}")
    refute home.id == summer.id
  end

  test "remains alive when a document is persisted", %{conn: conn, scope: scope} do
    page = scope |> Page.ensure!("Home")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home")

    assert :ok = page |> PageDocument.persist_collaboration("main", document("updated"))

    assert has_element?(view, "[data-testid='page-editor'][data-document-id='#{page.id}']")
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
             |> PageDocument.save(
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
    other_scope = create_scope("Other Space", scope.user)
    other_page = other_scope |> Page.ensure!("Private Page")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home")
    snapshot = document_snapshot("main", "Private content")

    assert {:ok, :saved} =
             other_scope
             |> PageDocument.save(
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

    assert [%{search_text: "Embedded content"}] =
             scope |> PageRevision.list!(embedded_page)

    assert [] = scope |> PageRevision.list!(containing_page)

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

    assert has_element?(view, "[data-testid='page-editor'][data-editable=false]")
    assert has_element?(view, "button[aria-label='Enable editing']")

    enable_editing(view)

    assert has_element?(view, "[data-testid='page-editor'][data-editable=true]")
    assert has_element?(view, "button[aria-label='End editing']")
    assert has_element?(view, "[data-testid='revisions-toggle']")

    view
    |> element("[data-testid='editing-toggle']")
    |> render_click()

    assert_push_event(view, "page_save_requested", %{})
    assert has_element?(view, "[data-testid='page-editor'][data-editable=false]")
    assert has_element?(view, "button[aria-label='Saving document'][disabled]")

    render_hook(view, "editing:save", %{
      "documents" => [document_snapshot("main", "Home content")]
    })

    assert_patch(view, ~p"/test-space/wiki/home")
    assert has_element?(view, "button[aria-label='Enable editing']")
    assert [page_document] = Ash.read!(PageDocument, scope: scope)
    assert page_document.search_text == "Home content"
    assert [revision] = Ash.read!(PageRevision, scope: scope)
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
    |> element("[data-testid='editing-toggle']")
    |> render_click()

    assert_push_event(view, "page_save_requested", %{})

    render_hook(view, "editing:save", %{"error" => "snapshot_failed"})

    assert has_element?(view, "[data-testid='page-editor'][data-editable=true]")
    assert has_element?(view, "button[aria-label='End editing']")
    assert render(view) =~ "Could not save the document"
  end

  test "renames a page from page info", %{conn: conn, scope: scope} do
    page = scope |> Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/summer-activities")

    open_title_edit(view)

    assert has_element?(
             view,
             "[data-testid='edit-title-form'] input[value='Summer Activities']"
           )

    view
    |> form("[data-testid='edit-title-form']", page_title: %{title: "Winter Activities"})
    |> render_submit()

    assert_push_event(view, "page_title_blur", %{})
    assert_patch(view, ~p"/test-space/wiki/winter-activities")
    assert Page.get!(page.id, scope: scope).title == "Winter Activities"
    assert Page.get!(page.id, scope: scope).slug == "winter-activities"

    refute has_element?(view, "[data-testid='edit-title-form']")
    assert has_element?(view, "h2", "Winter Activities")
  end

  test "propagates a rename to other viewers of the same page", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Summer Activities")
    {:ok, first_view, _html} = live(conn, ~p"/test-space/wiki/summer-activities")
    second_conn = conn |> recycle() |> log_in_user(scope.user)
    {:ok, second_view, _html} = live(second_conn, ~p"/test-space/wiki/summer-activities")

    open_title_edit(first_view)

    first_view
    |> form("[data-testid='edit-title-form']", page_title: %{title: "Winter Activities"})
    |> render_submit()

    assert_patch(second_view, ~p"/test-space/wiki/winter-activities")
    assert has_element?(second_view, "h2", "Winter Activities")
  end

  test "refreshes page references when another page is renamed", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")
    summer = scope |> Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home")

    Page.rename!(summer, "Winter Activities", scope: scope)

    assert has_element?(view, "[data-testid='page-editor'][data-pages*='Winter Activities']")
    refute has_element?(view, "[data-testid='page-editor'][data-pages*='Summer Activities']")
  end

  test "refreshes page references when another page is created", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home")

    scope |> Page.ensure!("Summer Activities")

    assert has_element?(view, "[data-testid='page-editor'][data-pages*='Summer Activities']")
  end

  test "cancels an unsaved page title", %{conn: conn, scope: scope} do
    page = scope |> Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/summer-activities")

    open_title_edit(view)

    view
    |> form("[data-testid='edit-title-form']", page_title: %{title: "Unsaved Title"})
    |> render_change()

    view
    |> element("[data-testid='edit-title-cancel']")
    |> render_click()

    refute has_element?(view, "[data-testid='edit-title-form']")
    assert has_element?(view, "[data-testid='edit-title-button']")
    assert Page.get!(page.id, scope: scope).title == "Summer Activities"
  end

  test "cancels an unsaved page title with Escape", %{conn: conn, scope: scope} do
    page = scope |> Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/summer-activities")

    open_title_edit(view)

    view
    |> form("[data-testid='edit-title-form']", page_title: %{title: "Unsaved Title"})
    |> render_change()

    view
    |> element("[data-testid='edit-title-form'] input")
    |> render_keydown(%{"key" => "Escape"})

    refute has_element?(view, "[data-testid='edit-title-form']")
    assert has_element?(view, "[data-testid='edit-title-button']")
    assert Page.get!(page.id, scope: scope).title == "Summer Activities"
  end

  test "shows title errors without renaming the page", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Winter Activities")
    page = scope |> Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/summer-activities")

    open_title_edit(view)

    view
    |> form("[data-testid='edit-title-form']", page_title: %{title: "Winter Activities"})
    |> render_submit()

    assert render(view) =~ "Not available"
    assert Page.get!(page.id, scope: scope).title == "Summer Activities"
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
    assert has_element?(view, "[aria-label='Enable editing']")
    assert has_element?(view, "a#previous-revision")
    assert has_element?(view, "button#next-revision[disabled]")

    view
    |> element("a#previous-revision")
    |> render_click()

    assert_patch(view, ~p"/test-space/wiki/home/revisions/1")
    assert has_element?(view, "#revision-preview-#{first_revision.id}")

    assert has_element?(
             view,
             "#revision-preview-#{first_revision.id}[data-previous-lexical-state='null']"
           )

    assert has_element?(view, "button#previous-revision[disabled]")
    assert has_element?(view, "a#next-revision")
    assert has_element?(view, "#current-page-editor.hidden #lexical-editor-#{page.id}")
  end

  test "shows an empty history before the first version", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home/revisions")

    assert render(view) =~ "No versions yet"
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

  test "does not open an out-of-range revision number", %{conn: conn, scope: scope} do
    scope |> Page.ensure!("Home")
    other_page = scope |> Page.ensure!("Other Page")
    _revision = scope |> create_revision(other_page, "Other content")

    assert_raise Ash.Error.Query.NotFound, fn ->
      live(conn, ~p"/test-space/wiki/home/revisions/1")
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

    {:ok, view, _html} = live(conn, ~p"/test-space/wiki/home/revisions/1")

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

    [preserved_revision | _revisions] = scope |> PageRevision.list!(page)
    assert preserved_revision.restored_from_revision_id == nil
    assert preserved_revision.search_text == "Unsaved collaborative edits"

    render_hook(view, "revisions:commit_restore", %{
      "documents" => [document_snapshot("main", "First version restored")],
      "revision_id" => source_revision.id
    })

    assert_patch(view, ~p"/test-space/wiki/home")

    [restored_revision, preserved_revision_after_restore | _revisions] =
      scope |> PageRevision.list!(page)

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
        get(conn, "/test-space/wiki/---")
      end

    assert Plug.Exception.status(error) == 404
    assert Ash.read!(Page, scope: scope) == []
  end

  defp document(text) do
    doc = Yex.Doc.new()
    doc |> Yex.Doc.get_text("content") |> Yex.Text.insert(0, text)
    doc
  end

  defp add_member(scope, user, display_name) do
    {:ok, membership} = scope |> Membership.invite(user.id)
    member_scope = %{scope | membership: membership, user: user}
    {:ok, membership} = member_scope |> Membership.accept(membership, display_name)

    %{member_scope | membership: membership}
  end

  defp enable_editing(view) do
    view
    |> element("[data-testid='editing-toggle']")
    |> render_click()

    refute_patched(view)
  end

  defp open_title_edit(view) do
    view
    |> element("[data-testid='page-info-toggle']")
    |> render_click()

    view
    |> element("[data-testid='edit-title-button']")
    |> render_click()
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
             |> PageRevision.record(
               page,
               %{
                 contributor_ids: contributor_ids,
                 lexical_state: document_snapshot("main", text)["lexical_state"],
                 search_text: text
               },
               nil
             )

    scope |> PageRevision.list!(page) |> List.first()
  end
end
