defmodule LexWeb.PageControllerTest do
  use LexWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "Hello"
    refute response =~ ~s(data-document-id=)
  end
end
