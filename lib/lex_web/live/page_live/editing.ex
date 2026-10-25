defmodule LexWeb.PageLive.Editing do
  use LexWeb, :live_view
  use LiveDelegate, path: [:editing]

  def on_mount(_params, _session, socket) do
    delegate_assign(socket, %{enabled?: false, title_form: nil})
  end

  def reload(socket, page) do
    delegate_assign(socket, :title_form, title_form(page))
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    editing = socket.assigns.editing
    socket = delegate_assign(socket, :enabled?, !editing.enabled?)

    {:noreply, socket}
  end

  def handle_event("title_change", %{"page_title" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.editing.title_form, params)
    socket = delegate_assign(socket, :title_form, form)

    {:noreply, socket}
  end

  def handle_event("title_reset", _params, socket) do
    socket = reload(socket, socket.assigns.page)

    {:noreply, socket}
  end

  def handle_event("title_save", %{"page_title" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.editing.title_form, params: params) do
      {:ok, _page} ->
        {:noreply, socket}

      {:error, form} ->
        socket =
          socket
          |> delegate_assign(:title_form, form)
          |> push_event("page_title_blur", %{})

        {:noreply, socket}
    end
  end

  defp title_form(page) do
    page
    |> AshPhoenix.Form.for_update(:rename, as: "page_title")
    |> to_form()
  end
end
