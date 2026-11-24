defmodule LexWeb.Router.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  use LexWeb, :live_view

  alias Lex.Accounts
  alias Lex.Scope
  alias LexWeb.Router.Path

  import Phoenix.Component

  def on_mount(:live_user_required, _params, _session, socket) do
    case socket.assigns[:current_user] do
      %Accounts.User{} = current_user ->
        scope = %Scope{user: current_user}
        socket = socket |> assign(scope: scope)
        {:cont, socket}

      nil ->
        socket = socket |> redirect(to: Path.dev_sign_in())
        {:halt, socket}
    end
  end
end
