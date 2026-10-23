defmodule LexWeb.WikiLiveTest do
  use LexWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Lex.Wiki.Page

  test "lists links to pages other than home", %{conn: conn} do
    Page.ensure!("Home")
    Page.ensure!("Summer Activities")

    {:ok, view, _html} = live(conn, ~p"/wiki")

    assert has_element?(view, ~s|a[href="/wiki/home"]|, "Home")
    assert has_element?(view, ~s|a[href="/wiki/summer-activities"]|, "Summer Activities")
  end

  test "updates a page link after the page is renamed", %{conn: conn} do
    page = Page.ensure!("Summer Activities")
    {:ok, view, _html} = live(conn, ~p"/wiki")

    Page.rename!(page, "Winter Activities")

    assert has_element?(view, ~s|a[href="/wiki/winter-activities"]|, "Winter Activities")
    refute has_element?(view, ~s|a[href="/wiki/summer-activities"]|)
  end

  test "adds a page link after the page is created", %{conn: conn} do
    Page.ensure!("Home")
    {:ok, view, _html} = live(conn, ~p"/wiki")

    Page.ensure!("Summer Activities")

    assert has_element?(view, ~s|a[href="/wiki/summer-activities"]|, "Summer Activities")
  end
end
