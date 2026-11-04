defmodule LexWeb.DevAuthLiveTest do
  use LexWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Lex.Accounts.User

  test "renders the dev users", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev/auth/sign-in")

    assert has_element?(view, "h1", "Choose a user")

    for {key, display_name} <- [
          {"tom", "Tom"},
          {"sandra", "Sandra"},
          {"john", "John"},
          {"alice", "Alice"}
        ] do
      assert has_element?(view, "[data-testid='dev-user'][data-user='#{key}']", display_name)
    end
  end

  test "creates and authenticates a selected user", %{conn: conn} do
    conn = post(conn, "/dev/auth/sign-in", %{"user" => "tom"})

    assert redirected_to(conn) == ~p"/"
    assert is_binary(get_session(conn, "user_token"))

    assert [%User{display_name: "Tom", hue: 25}] = Ash.read!(User, authorize?: false)
  end

  test "reuses the selected user", %{conn: conn} do
    path = "/dev/auth/sign-in"
    conn = post(conn, path, %{"user" => "alice"})
    conn = conn |> recycle() |> post(path, %{"user" => "alice"})

    assert redirected_to(conn) == ~p"/"
    assert [%User{display_name: "Alice", hue: 295}] = Ash.read!(User, authorize?: false)
  end

  test "switches the authenticated user", %{conn: conn} do
    path = "/dev/auth/sign-in"
    conn = post(conn, path, %{"user" => "tom"})
    conn = conn |> recycle() |> post(path, %{"user" => "sandra"})
    session = get_session(conn)

    assert {:ok, %User{display_name: "Sandra", hue: 115}} =
             AshAuthentication.Plug.Helpers.authenticate_resource_from_session(
               User,
               session,
               :lex,
               []
             )
  end

  test "rejects users outside the dev-user catalog", %{conn: conn} do
    conn = post(conn, "/dev/auth/sign-in", %{"user" => "mallory"})

    assert redirected_to(conn) == "/dev/auth/sign-in"
    assert Ash.read!(User, authorize?: false) == []
  end

  test "requires authentication for application LiveViews", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert redirected_to(conn) == "/dev/auth/sign-in"
  end

  test "signs out before the app redirects to the dev-user picker", %{conn: conn} do
    current_user = create_user()

    conn =
      conn
      |> log_in_user(current_user)
      |> delete(~p"/sign-out")

    assert redirected_to(conn) == "/"
    assert get_session(conn, "user_token") == nil

    conn = conn |> recycle() |> get(~p"/")

    assert redirected_to(conn) == "/dev/auth/sign-in"
  end
end
