defmodule LexWeb.HomeLiveTest do
  use LexWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Lex.Accounts
  alias Lex.Accounts.Space

  setup :authenticate

  test "lists existing spaces and creates a space", %{
    conn: conn,
    current_user: current_user
  } do
    scope = %Lex.Scope{user: current_user}
    existing_space = Space.create!(%{name: "Existing Space"}, scope: scope)

    {:ok, view, _html} = live(conn, ~p"/")

    refute has_element?(view, "[data-testid='space-creation-form']")

    assert has_element?(
             view,
             "[data-testid='space'][href='/#{existing_space.slug}']",
             "Existing Space"
           )

    assert has_element?(
             view,
             "[data-testid='space'][href='/#{existing_space.slug}']",
             "Invitation"
           )

    view
    |> element("[data-testid='show-space-form']")
    |> render_click()

    refute has_element?(view, "[data-testid='space']")
    assert has_element?(view, "[data-testid='space-creation-form']")
    refute has_element?(view, "[data-testid='space-creation-form'] input[name='space[slug]']")

    view
    |> form("[data-testid='space-creation-form']", space: %{name: "Discarded Space"})
    |> render_change()

    view
    |> element("[data-testid='cancel-space-creation']")
    |> render_click()

    assert has_element?(view, "[data-testid='space']", "Existing Space")
    refute has_element?(view, "[data-testid='space-creation-form']")

    view
    |> element("[data-testid='show-space-form']")
    |> render_click()

    refute render(element(view, "[data-testid='space-creation-form']")) =~ "Discarded Space"

    view
    |> form("[data-testid='space-creation-form']",
      space: %{
        name: "New Space",
        description: "A new place to write"
      }
    )
    |> render_submit()

    assert_redirect(view, ~p"/new-space/join")

    assert [
             %{space: %{name: "Existing Space"}, status: :invited},
             %{space: %{name: "New Space"}, status: :invited}
           ] = scope |> Accounts.list_memberships!()
  end
end
