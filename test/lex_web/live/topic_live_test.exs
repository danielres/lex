defmodule LexWeb.TopicLiveTest do
  use LexWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Lex.Topics.Topic

  setup :authenticate

  setup %{current_user: user} do
    scope = create_scope("Test Space", user)

    topic =
      Topic
      |> Ash.Changeset.for_create(:create, %{name: "Summer Plans"}, scope: scope)
      |> Ash.create!()

    %{scope: scope, topic: topic}
  end

  test "patches both open topic views after a rename", %{conn: conn, scope: scope} do
    {:ok, first, _html} = live(conn, ~p"/test-space/topics/summer-plans")
    second_conn = conn |> recycle() |> log_in_user(scope.user)
    {:ok, second, _html} = live(second_conn, ~p"/test-space/topics/summer-plans")

    first
    |> open_rename()
    |> form("[data-testid='rename-form']", rename: %{name: "Winter Plans"})
    |> render_submit()

    for view <- [first, second] do
      assert_patch(view, ~p"/test-space/topics/winter-plans")
      assert has_element?(view, "h2", "Winter Plans")
      refute has_element?(view, "[data-testid='rename-form']")
    end
  end

  test "updates a same-slug name in place and closes an unchanged form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/test-space/topics/summer-plans")

    view
    |> open_rename()
    |> form("[data-testid='rename-form']", rename: %{name: "Summer plans"})
    |> render_submit()

    assert has_element?(view, "h2", "Summer plans")
    refute_patched(view)

    view
    |> open_rename()
    |> form("[data-testid='rename-form']", rename: %{name: "Summer plans"})
    |> render_submit()

    refute has_element?(view, "[data-testid='rename-form']")
    refute_patched(view)
  end

  test "keeps errors in the form and discards them on Escape", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/test-space/topics/summer-plans")

    view
    |> open_rename()
    |> form("[data-testid='rename-form']", rename: %{name: "!!"})
    |> render_submit()

    assert has_element?(view, "[data-testid='rename-form']", "must contain at least one letter or number")

    view
    |> element("[data-testid='rename-form']")
    |> render_keydown(%{"key" => "Escape"})

    refute has_element?(view, "[data-testid='rename-form']")
    assert has_element?(view, "[data-testid='rename-open']")
  end

  defp open_rename(view) do
    view |> element("[data-testid='topic-info-toggle']") |> render_click()
    view |> element("[data-testid='rename-open']") |> render_click()
    view
  end
end
