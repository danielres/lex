defmodule LexWeb.Router.LiveSpaceAccess do
  @moduledoc """
  Establishes and maintains space access for routed LiveViews.

  It resolves the current space and membership during mount, keeps the membership
  synchronized while connected, and routes the user when their access changes.

  Immediately blocks and redirects a member when their space access is revoked.
  """

  use LexWeb, :live_view

  alias Ash.Notifier.Notification
  alias Lex.Accounts.Membership
  alias Lex.Accounts.Space
  alias LexWeb.Router.Path

  def on_mount(:default, %{"space_slug" => slug}, _session, socket) do
    scope = socket.assigns.scope
    space = Space.get_by_slug!(slug, scope: scope)
    scope = %{scope | space: space}
    socket = socket |> assign(scope: scope)

    socket =
      if connected?(socket) do
        :ok = scope |> Membership.subscribe()
        socket |> attach_hook(:space_access, :handle_info, &revalidate_space_access/2)
      else
        socket
      end

    {socket, destination} = refresh_membership(socket)

    case destination do
      nil -> {:cont, socket}
      path -> {:halt, socket |> redirect(to: path)}
    end
  end

  def on_mount(:default, _params, _session, socket), do: {:cont, socket}

  defp revalidate_space_access(%Notification{resource: Membership}, socket) do
    {socket, destination} = refresh_membership(socket)

    socket =
      case destination do
        nil -> socket
        path -> socket |> push_navigate(to: path)
      end

    {:halt, socket}
  end

  defp revalidate_space_access(_message, socket), do: {:cont, socket}

  defp refresh_membership(socket) do
    scope = socket.assigns.scope

    scope
    |> Membership.get()
    |> case do
      {:ok, %Membership{} = membership} ->
        scope = %{scope | membership: membership}
        live_action = socket.assigns.live_action

        destination = scope |> membership_destination(membership, live_action)
        socket = socket |> assign(scope: scope)

        {socket, destination}

      {:ok, nil} ->
        {socket, Path.spaces()}

      {:error, _error} ->
        {socket, Path.spaces()}
    end
  end

  defp membership_destination(scope, membership, live_action) do
    case {membership.status, live_action} do
      {:active, :join} -> Path.to(scope.space)
      {:active, _live_action} -> nil
      {:invited, :join} -> nil
      {:invited, _live_action} -> Path.onboarding(scope)
      {_status, _live_action} -> Path.spaces()
    end
  end
end
