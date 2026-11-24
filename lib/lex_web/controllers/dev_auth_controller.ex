defmodule LexWeb.DevAuthController do
  use LexWeb, :controller
  use AshAuthentication.Phoenix.Controller

  alias LexWeb.Router.Path

  def success(conn, _activity, user, _token) do
    conn
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: Path.spaces())
  end

  def failure(conn, _activity, _reason) do
    conn
    |> put_flash(:error, "Could not sign in")
    |> redirect(to: Path.dev_sign_in())
  end

  defdelegate sign_out(conn, params), to: LexWeb.AuthController
end
