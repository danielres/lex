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
end
