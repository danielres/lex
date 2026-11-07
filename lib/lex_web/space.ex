defmodule LexWeb.Space do
  use LexWeb, :live_view
  use LiveDelegate, path: [:space]

  alias Ash.Error.Query.NotFound
  alias Lex.Accounts
  alias Lex.Accounts.Membership

  def on_mount(%{"space_slug" => slug}, _session, socket) do
    scope = socket.assigns.scope
    space = Accounts.Space.get_by_slug!(slug, scope: scope)
    scope = %{scope | space_id: space.id}

    membership =
      scope
      |> Accounts.get_membership(scope.current_user)
      |> case do
        {:ok, %Membership{} = membership} -> membership
        {:ok, nil} -> raise NotFound, resource: Membership, primary_key: nil
        {:error, error} -> raise error
      end

    scope = %{scope | current_membership: membership}

    socket
    |> delegate_assign(space)
    |> assign(:scope, scope)
    |> route_membership(membership)
  end

  defp route_membership(socket, %{status: :active}) do
    if socket.assigns.live_action == :join do
      socket |> redirect(to: ~p"/#{socket.assigns.space.slug}")
    else
      socket
    end
  end

  defp route_membership(socket, %{status: :invited}) do
    if socket.assigns.live_action == :join do
      socket
    else
      socket |> redirect(to: ~p"/#{socket.assigns.space.slug}/join")
    end
  end

  defp route_membership(_socket, _membership) do
    raise NotFound, resource: Membership, primary_key: nil
  end
end
