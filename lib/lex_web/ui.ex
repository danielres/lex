defmodule LexWeb.UI do
  use LexWeb, :live_view
  use LiveDelegate, path: [:ui]

  def handle_event("toggle_drawer", _params, socket) do
    open? = socket.assigns.ui.drawer_open?

    socket =
      socket
      |> delegate_assign(%{drawer_open?: !open?})

    {:noreply, socket}
  end

  def on_mount(_params, _session, socket) do
    socket
    |> delegate_assign(%{drawer_open?: false})
  end
end
