defmodule LexWeb.PageLiveTest do
  use LexWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Lex.Wiki.Page

  test "a direct visit creates the page and binds the editor to its id", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/wiki/home")
    [page] = Ash.read!(Page)

    assert html =~ ~s(data-document-id="#{page.id}")
    assert html =~ ~s(id="lexical-editor-#{page.id}")
    assert page.title == "Home"
  end

  test "preloads page references and creates missing link targets", %{conn: conn} do
    Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/wiki/home")

    assert has_element?(view, "[phx-hook=LexicalEditor][data-pages*='Summer Activities']")

    render_hook(view, "ensure_wiki_page", %{"title" => "Winter Plans"})

    assert Page.list!() |> Enum.any?(&(&1.title == "Winter Plans"))
  end

  test "revisiting a slug reuses its page id", %{conn: conn} do
    {:ok, _view, first_html} = live(conn, ~p"/wiki/summer-activities")
    [page] = Ash.read!(Page)

    {:ok, _view, second_html} = live(recycle(conn), ~p"/wiki/summer-activities")

    assert first_html =~ ~s(data-document-id="#{page.id}")
    assert second_html =~ ~s(data-document-id="#{page.id}")
    assert length(Ash.read!(Page)) == 1
  end

  test "different slugs use different collaboration document ids", %{conn: conn} do
    {:ok, _view, home_html} = live(conn, ~p"/wiki/home")
    {:ok, _view, summer_html} = live(recycle(conn), ~p"/wiki/summer-activities")

    [home, summer] = Page |> Ash.Query.sort(:slug) |> Ash.read!()

    assert home_html =~ ~s(data-document-id="#{home.id}")
    assert summer_html =~ ~s(data-document-id="#{summer.id}")
    refute home.id == summer.id
  end

  test "the lock button toggles whether the editor is editable", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/wiki/home")

    assert has_element?(view, "[phx-hook=LexicalEditor][data-editable=false]")
    assert has_element?(view, "button[aria-label='Enable editing']")

    view
    |> element("button[phx-click=toggle_editable]")
    |> render_click()

    assert has_element?(view, "[phx-hook=LexicalEditor][data-editable=true]")
    assert has_element?(view, "button[aria-label='Make editor read-only']")
  end

  test "renames a page and patches to its new slug", %{conn: conn} do
    page = Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/wiki/summer-activities")

    view
    |> element("button[phx-click=toggle_editable]")
    |> render_click()

    assert has_element?(view, "#page-title-form input[value='Summer Activities']")

    view
    |> form("#page-title-form", page_title: %{title: "Winter Activities"})
    |> render_submit()

    assert_push_event(view, "page_title_blur", %{})
    assert_patch(view, ~p"/wiki/winter-activities")
    assert Page.get!(page.id).title == "Winter Activities"
    assert Page.get!(page.id).slug == "winter-activities"
    assert has_element?(view, "#page-title-form input[value='Winter Activities']")
  end

  test "propagates a rename to other viewers of the same page", %{conn: conn} do
    Page.ensure!("Summer Activities")
    {:ok, first_view, _html} = live(conn, ~p"/wiki/summer-activities")
    {:ok, second_view, _html} = live(recycle(conn), ~p"/wiki/summer-activities")

    first_view
    |> element("button[phx-click=toggle_editable]")
    |> render_click()

    first_view
    |> form("#page-title-form", page_title: %{title: "Winter Activities"})
    |> render_submit()

    assert_patch(first_view, ~p"/wiki/winter-activities")
    assert_patch(second_view, ~p"/wiki/winter-activities")
    assert has_element?(second_view, "h1", "Winter Activities")
  end

  test "refreshes page references when another page is renamed", %{conn: conn} do
    Page.ensure!("Home")
    summer = Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/wiki/home")

    Page.rename!(summer, "Winter Activities")

    assert has_element?(view, "[phx-hook=LexicalEditor][data-pages*='Winter Activities']")
    refute has_element?(view, "[phx-hook=LexicalEditor][data-pages*='Summer Activities']")
  end

  test "refreshes page references when another page is created", %{conn: conn} do
    Page.ensure!("Home")
    {:ok, view, _html} = live(conn, ~p"/wiki/home")

    Page.ensure!("Summer Activities")

    assert has_element?(view, "[phx-hook=LexicalEditor][data-pages*='Summer Activities']")
  end

  test "resets an unsaved page title", %{conn: conn} do
    Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/wiki/summer-activities")

    view
    |> element("button[phx-click=toggle_editable]")
    |> render_click()

    view
    |> form("#page-title-form", page_title: %{title: "Unsaved Title"})
    |> render_change()

    view
    |> element("button[aria-label='Cancel title change']")
    |> render_click()

    assert has_element?(view, "#page-title-form input[value='Summer Activities']")
  end

  test "resets an unsaved page title when the input loses focus", %{conn: conn} do
    Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/wiki/summer-activities")

    view
    |> element("button[phx-click=toggle_editable]")
    |> render_click()

    view
    |> form("#page-title-form", page_title: %{title: "Unsaved Title"})
    |> render_change()

    view
    |> element("#page_title_title")
    |> render_blur()

    assert has_element?(view, "#page-title-form input[value='Summer Activities']")
  end

  test "resets an unsaved page title with Escape", %{conn: conn} do
    Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/wiki/summer-activities")

    view
    |> element("button[phx-click=toggle_editable]")
    |> render_click()

    view
    |> form("#page-title-form", page_title: %{title: "Unsaved Title"})
    |> render_change()

    view
    |> element("#page_title_title")
    |> render_keydown(%{"key" => "Escape"})

    assert has_element?(view, "#page-title-form input[value='Summer Activities']")
  end

  test "shows title errors without renaming the page", %{conn: conn} do
    Page.ensure!("Winter Activities")
    page = Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/wiki/summer-activities")

    view
    |> element("button[phx-click=toggle_editable]")
    |> render_click()

    view
    |> form("#page-title-form", page_title: %{title: "Winter Activities"})
    |> render_submit()

    assert render(view) =~ "Not available"
    assert Page.get!(page.id).title == "Summer Activities"
  end

  test "does not offer title editing for the home page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/wiki/home")

    view
    |> element("button[phx-click=toggle_editable]")
    |> render_click()

    refute has_element?(view, "#page-title-form")
  end

  test "invalid slugs return not found and do not create pages", %{conn: conn} do
    error =
      assert_raise Ash.Error.Query.NotFound, fn ->
        get(conn, "/wiki/Summer-Activities")
      end

    assert Plug.Exception.status(error) == 404
    assert Ash.read!(Page) == []
  end
end
