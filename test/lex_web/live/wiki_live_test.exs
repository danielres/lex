defmodule LexWeb.WikiLiveTest do
  use LexWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Lex.Wiki.Page

  test "lists links to pages other than home", %{conn: conn} do
    Page.ensure!("Home")
    Page.ensure!("Summer Activities")

    {:ok, view, _html} = live(conn, ~p"/test-space/wiki")

    assert has_element?(view, ~s|a[href="/test-space/wiki/home"]|, "Home")

    assert has_element?(
             view,
             ~s|a[href="/test-space/wiki/summer-activities"]|,
             "Summer Activities"
           )
  end

  test "updates a page link after the page is renamed", %{conn: conn} do
    page = Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki")

    Page.rename!(page, "Winter Activities")

    assert has_element?(
             view,
             ~s|a[href="/test-space/wiki/winter-activities"]|,
             "Winter Activities"
           )

    refute has_element?(view, ~s|a[href="/test-space/wiki/summer-activities"]|)
  end

  test "adds a page link after the page is created", %{conn: conn} do
    Page.ensure!("Home")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki")

    Page.ensure!("Summer Activities")

    assert has_element?(
             view,
             ~s|a[href="/test-space/wiki/summer-activities"]|,
             "Summer Activities"
           )
  end

  test "sorts pages by a column and toggles its direction", %{conn: conn} do
    Page.ensure!("Winter Activities")
    Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki")

    assert has_element?(
             view,
             "th[aria-sort=descending] button[phx-value-sort-by=last_updated_at]"
           )

    view
    |> element("button[phx-value-sort-by=title]")
    |> render_click()

    assert has_element?(view, "th[aria-sort=ascending] button[phx-value-sort-by=title]")
    assert has_element?(view, "tbody tr:first-child", "Summer Activities")

    view
    |> element("button[phx-value-sort-by=title]")
    |> render_click()

    assert has_element?(view, "th[aria-sort=descending] button[phx-value-sort-by=title]")
    assert has_element?(view, "tbody tr:first-child", "Winter Activities")
  end

  test "keeps the selected sort when pages change", %{conn: conn} do
    page = Page.ensure!("Summer Activities")
    Page.ensure!("Winter Activities")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki")

    view
    |> element("button[phx-value-sort-by=title]")
    |> render_click()

    Page.rename!(page, "Autumn Activities")

    assert has_element?(view, "th[aria-sort=ascending] button[phx-value-sort-by=title]")
    assert has_element?(view, "tbody tr:first-child", "Autumn Activities")
  end

  test "sorts and refreshes pages by their latest document checkpoint", %{conn: conn} do
    first_page = Page.ensure!("First Page")
    Page.ensure!("Second Page")
    {:ok, view, _html} = live(conn, ~p"/test-space/wiki")

    assert :ok = Page.set_checkpoint(first_page, "main", document("updated"))

    assert has_element?(view, "tbody tr:first-child", "First Page")
  end

  defp document(text) do
    doc = Yex.Doc.new()
    doc |> Yex.Doc.get_text("content") |> Yex.Text.insert(0, text)
    doc
  end
end
