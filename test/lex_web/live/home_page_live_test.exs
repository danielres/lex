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
    first_scope = create_scope("First Space", current_user)
    second_scope = create_scope("Second Space", current_user)
    first_space = Ash.get!(Space, first_scope.space_id, scope: first_scope)
    second_space = Ash.get!(Space, second_scope.space_id, scope: second_scope)

    {:ok, first_view, _html} = live(conn, ~p"/#{first_space.slug}/wiki/home")
    second_conn = conn |> recycle() |> log_in_user(current_user)
    {:ok, second_view, _html} = live(second_conn, ~p"/#{second_space.slug}/wiki/home")

    refute has_element?(first_view, "[data-testid='missing-page']")
    refute has_element?(second_view, "[data-testid='missing-page']")
    assert has_element?(first_view, "[data-testid='page-author']", current_user.display_name)
    assert has_element?(second_view, "[data-testid='page-author']", current_user.display_name)

    assert [
             %{
               author_id: first_author_id,
               space_id: first_space_id,
               title: "Home",
               slug: "home"
             }
           ] =
             Page.list!(scope: first_scope)

    assert [
             %{
               author_id: second_author_id,
               space_id: second_space_id,
               title: "Home",
               slug: "home"
             }
           ] =
             Page.list!(scope: second_scope)

    assert first_author_id == current_user.id
    assert second_author_id == current_user.id
    assert first_space_id == first_space.id
    assert second_space_id == second_space.id
  end

  test "continues to offer creation for other missing pages", %{
    conn: conn,
    current_user: current_user
  } do
    scope = create_scope("Test Space", current_user)
    space = Ash.get!(Space, scope.space_id, scope: scope)

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
