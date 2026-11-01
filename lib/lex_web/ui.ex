defmodule LexWeb.UI do
  use LexWeb, :live_view
  use LiveDelegate, path: [:ui]

  def toggle_drawer_event, do: delegate_event("toggle_drawer")

  def handle_event("toggle_drawer", _params, socket) do
    open? = socket.assigns.ui.drawer_open?

    socket =
      socket
      |> delegate_assign(%{drawer_open?: !open?})

    {:noreply, socket}
  end

  def on_mount(_params, _session, socket) do
    delegate_assign(socket, %{drawer_open?: false})
  end
end
