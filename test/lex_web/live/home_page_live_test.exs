defmodule LexWeb.HomePageLiveTest do
  use LexWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Lex.Accounts.Space
  alias Lex.Wiki.Page

  setup :authenticate

  test "creates a missing home page automatically within its space", %{
    conn: conn,
    current_user: current_user
  } do
    scope = %Lex.Scope{current_user: current_user}
    first_space = Space.create!(%{name: "First Space"}, scope: scope)
    second_space = Space.create!(%{name: "Second Space"}, scope: scope)
    first_scope = %{scope | space_id: first_space.id}
    second_scope = %{scope | space_id: second_space.id}

    {:ok, first_view, _html} = live(conn, ~p"/#{first_space.slug}/wiki/home")
    second_conn = conn |> recycle() |> log_in_user(current_user)
    {:ok, second_view, _html} = live(second_conn, ~p"/#{second_space.slug}/wiki/home")

    refute has_element?(first_view, "[data-testid='missing-page']")
    refute has_element?(second_view, "[data-testid='missing-page']")

    assert [%{space_id: first_space_id, title: "Home", slug: "home"}] =
             Page.list!(scope: first_scope)

    assert [%{space_id: second_space_id, title: "Home", slug: "home"}] =
             Page.list!(scope: second_scope)

    assert first_space_id == first_space.id
    assert second_space_id == second_space.id
  end

  test "continues to offer creation for other missing pages", %{
    conn: conn,
    current_user: current_user
  } do
    scope = %Lex.Scope{current_user: current_user}
    space = Space.create!(%{name: "Test Space"}, scope: scope)
    scope = %{scope | space_id: space.id}

    {:ok, view, _html} = live(conn, ~p"/#{space.slug}/wiki/new-page")

    assert has_element?(view, "[data-testid='missing-page']")
    assert Page.list!(scope: scope) == []

    view
    |> form("[data-testid='page-creation-form']", page: %{title: "New Page"})
    |> render_submit()

    assert_redirect(view, ~p"/#{space.slug}/wiki/new-page")

    assert [%{space_id: space_id, title: "New Page", slug: "new-page"}] =
             Page.list!(scope: scope)

    assert space_id == space.id
  end
end
