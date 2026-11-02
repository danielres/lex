defmodule LexWeb.UI do
  use LexWeb, :live_view
  use LiveDelegate, path: [:ui]

  @local_settings_changed_event "local-settings-changed"

  def toggle_drawer_event, do: delegate_event("toggle_drawer")

  def handle_event("toggle_drawer", _params, socket) do
    drawer_open? = !socket.assigns.ui.drawer_open?

    socket =
      socket
      |> delegate_assign(%{drawer_open?: drawer_open?})
      |> push_event(@local_settings_changed_event, %{drawer: %{open: drawer_open?}})

    {:noreply, socket}
  end

  def on_mount(_params, _session, socket) do
    drawer_open? =
      case get_connect_params(socket) do
        %{"local_settings" => %{"drawer" => %{"open" => open?}}}
        when is_boolean(open?) ->
          open?

        _other ->
          false
      end

    delegate_assign(socket, %{drawer_open?: drawer_open?})
  end
end
