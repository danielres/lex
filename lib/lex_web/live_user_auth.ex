defmodule LexWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component

  def on_mount(:live_user_required, _params, _session, socket) do
    case socket.assigns[:current_user] do
      %Lex.Accounts.User{} = current_user ->
        scope = %Lex.Scope{user: current_user}
        {:cont, assign(socket, :scope, scope)}

      nil ->
        {:halt, Phoenix.LiveView.redirect(socket, to: "/dev/auth/sign-in")}
    end
  end
end
