defmodule LexWeb.PresencesLiveTest do
  use LexWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders the connected collaborator", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "[data-testid=presence]")
    assert has_element?(view, "[data-testid=presences-expanded-count]", "1")
    assert has_element?(view, "[data-testid=presences-collapsed-count]", "1")
  end

  test "renders as a sticky child LiveView", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "[data-testid=presences-live][data-phx-sticky]")
  end

  test "collapsed presence control delegates to the parent drawer toggle", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(
             view,
             "[data-testid=presences-toggle][phx-click*='drawer-toggle']"
           )

    assert has_element?(view, "[data-testid=drawer][data-drawer-open=false]")

    view
    |> element("[data-testid=drawer-toggle]")
    |> render_click()

    assert has_element?(view, "[data-testid=drawer][data-drawer-open=true]")
  end
end
