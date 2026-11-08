defmodule LexWeb.Space do
  use LexWeb, :live_view

  alias Ash.Error.Query.NotFound
  alias Lex.Accounts.Membership
  alias Lex.Accounts.Space

  def on_mount(%{"space_slug" => slug}, _session, socket) do
    scope = socket.assigns.scope
    space = Space.get_by_slug!(slug, scope: scope)
    scope = %{scope | space: space}

    membership =
      scope
      |> Membership.get()
      |> case do
        {:ok, %Membership{} = membership} -> membership
        {:ok, nil} -> raise NotFound, resource: Membership, primary_key: nil
        {:error, error} -> raise error
      end

    scope = %{scope | membership: membership}

    socket
    |> assign(:scope, scope)
    |> route_membership(membership)
  end

  defp route_membership(socket, %{status: :active}) do
    if socket.assigns.live_action == :join do
      socket |> redirect(to: ~p"/#{socket.assigns.scope.space.slug}")
    else
      socket
    end
  end

  defp route_membership(socket, %{status: :invited}) do
    if socket.assigns.live_action == :join do
      socket
    else
      socket |> redirect(to: ~p"/#{socket.assigns.scope.space.slug}/join")
    end
  end

  defp route_membership(_socket, _membership) do
    raise NotFound, resource: Membership, primary_key: nil
  end
end
