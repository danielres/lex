defmodule LexWeb.PageLiveTest do
  use LexWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Lex.Wiki.Page

  test "a direct visit creates the page and binds the editor to its id", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/wiki/home")
    [page] = Ash.read!(Page)

    assert html =~ ~s(data-document-id="#{page.id}")
    assert html =~ ~s(id="lexical-editor-#{page.id}")
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

  test "invalid slugs return not found and do not create pages", %{conn: conn} do
    error =
      assert_raise Ash.Error.Query.NotFound, fn ->
        get(conn, "/wiki/Summer-Activities")
      end

    assert Plug.Exception.status(error) == 404
    assert Ash.read!(Page) == []
  end
end
