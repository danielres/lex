defmodule LexWeb.PageLive.Editing do
  use LexWeb, :live_view
  use LiveDelegate, path: [:editing]

  alias Lex.Collaboration

  def on_mount(_params, _session, socket) do
    delegate_assign(socket, %{checkpointing?: false, title_form: nil})
  end

  def reload(socket, page) do
    delegate_assign(socket, :title_form, title_form(page))
  end

  def checkpoint_event, do: delegate_event("checkpoint")
  def snapshot_request_event, do: "document_snapshot_requested"

  @impl true
  def handle_event("toggle", _params, socket) do
    editing = socket.assigns.editing

    socket =
      cond do
        editing.checkpointing? ->
          socket

        socket.assigns.live_action == :editing ->
          socket
          |> delegate_assign(:checkpointing?, true)
          |> push_event(snapshot_request_event(), %{})

        true ->
          assign(socket, :live_action, :editing)
      end

    {:noreply, socket}
  end

  def handle_event("checkpoint", %{"documents" => documents}, socket)
      when is_list(documents) do
    case Collaboration.checkpoint(socket.assigns.page, documents) do
      {:ok, counts} ->
        socket =
          socket
          |> delegate_assign(:checkpointing?, false)
          |> assign(:live_action, :show)
          |> push_patch(replace: true, to: ~p"/wiki/#{socket.assigns.page.slug}")

        {:reply, %{ok: true, result: counts}, socket}

      {:error, _reason} ->
        checkpoint_failed(socket)
    end
  end

  def handle_event("checkpoint", _params, socket), do: checkpoint_failed(socket)

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

  defp checkpoint_failed(socket) do
    socket =
      socket
      |> delegate_assign(:checkpointing?, false)
      |> put_flash(:error, "Could not save the document")

    {:reply, %{ok: false}, socket}
  end
end
