defmodule LexWeb.PageControllerTest do
  use LexWeb.ConnCase

  setup :authenticate

  test "GET / renders the spaces home", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "Your spaces"
  end
end
