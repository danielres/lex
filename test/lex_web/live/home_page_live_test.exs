defmodule LexWeb.HomePageLiveTest do
  use LexWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Lex.Accounts.Space
  alias Lex.Wiki.Page

  test "creates a missing home page automatically within its space", %{conn: conn} do
    first_space = Space.create!(%{name: "First Space"})
    second_space = Space.create!(%{name: "Second Space"})

    {:ok, first_view, _html} = live(conn, ~p"/#{first_space.slug}/wiki/home")
    {:ok, second_view, _html} = live(recycle(conn), ~p"/#{second_space.slug}/wiki/home")

    refute has_element?(first_view, "[data-testid='missing-page']")
    refute has_element?(second_view, "[data-testid='missing-page']")

    assert [
             %{space_id: first_space_id, title: "Home", slug: "home"},
             %{space_id: second_space_id, title: "Home", slug: "home"}
           ] = Page.list!()

    assert Enum.sort([first_space_id, second_space_id]) ==
             Enum.sort([first_space.id, second_space.id])
  end

  test "continues to offer creation for other missing pages", %{conn: conn} do
    space = Space.create!(%{name: "Test Space"})

    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/wiki/new-page")

    assert has_element?(view, "[data-testid='missing-page']")
    assert Page.list!() == []

    view
    |> form("[data-testid='page-creation-form']", page: %{title: "New Page"})
    |> render_submit()

    assert_redirect(view, ~p"/#{space.slug}/wiki/new-page")
    assert [%{space_id: space_id, title: "New Page", slug: "new-page"}] = Page.list!()
    assert space_id == space.id
  end
end
