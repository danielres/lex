defmodule LexWeb.HomeLiveTest do
  use LexWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Lex.Accounts.Space

  test "lists existing spaces and creates a space", %{conn: conn} do
    existing_space = Space.create!(%{name: "Existing Space"})

    {:ok, view, _html} = live(conn, ~p"/")

    refute has_element?(view, "[data-testid='space-creation-form']")

    assert has_element?(
             view,
             "[data-testid='space'][href='/#{existing_space.slug}']",
             "Existing Space"
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

    assert has_element?(view, "[data-testid='space'][href='/new-space']", "New Space")
    refute has_element?(view, "[data-testid='space-creation-form']")
    assert [%{name: "Existing Space"}, %{name: "New Space"}] = Space.list!()
  end
end
