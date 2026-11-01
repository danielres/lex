defmodule LexWeb.Presences do
  use LexWeb, :live_view
  use LiveDelegate, path: [:presences]

  alias LexWeb.Components.Avatar

  @room_key "DEFAULT_TEMP_ROOM"

  def on_mount(_params, _session, socket) do
    socket
    |> monitor()
    |> join()
    |> delegate_assign(%{data: get_presences()})
  end

  defp monitor(socket) do
    if connected?(socket) do
      :ok = Group.monitor(:lex, @room_key)
    end

    socket
  end

  defp join(socket) do
    if connected?(socket) do
      collaborator = socket.assigns.collaborator
      :ok = Group.join(:lex, @room_key, collaborator)
    end

    socket
  end

  defp get_presences() do
    Group.members(:lex, @room_key)
    |> Enum.map(fn {pid, presence} -> presence end)
    |> Enum.sort_by(fn user -> user.display_name end)
  end

  def handle_info({_events, _info}, socket) do
    socket = socket |> delegate_assign(%{data: get_presences()})
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div
      :for={presence <- @presences.data}
      phx-hook="AutoAnimate"
      id={"presence-#{presence.display_name}"}
    >
      <Avatar.render user={presence} />
    </div>
    """
  end
end
