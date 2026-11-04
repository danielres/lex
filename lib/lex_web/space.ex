defmodule LexWeb.Space do
  use LexWeb, :live_view
  use LiveDelegate, path: [:space]

  alias Lex.Accounts

  def on_mount(%{"space_slug" => slug}, _session, socket) do
    scope = socket.assigns.scope
    space = Accounts.Space.get_by_slug!(slug, scope: scope)
    scope = %{scope | space_id: space.id}

    socket
    |> delegate_assign(space)
    |> assign(:scope, scope)
  end
end
