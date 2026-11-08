defmodule LexWeb.CollaborationChannel do
  use LexWeb, :channel

  alias Lex.Collaboration
  alias Yex.Sync
  alias Yex.Sync.SharedDoc

  @impl true
  def join("y_doc:" <> room, _payload, socket) when room != "" do
    with {:ok, shared_doc} <- Collaboration.open_document(socket.assigns.scope, room),
         :ok <- SharedDoc.observe(shared_doc) do
      socket = socket |> assign(room: room, shared_doc: shared_doc)

      {:ok, socket}
    else
      {:error, reason} -> {:error, %{reason: inspect(reason)}}
    end
  end

  @impl true
  def handle_in("yjs_sync", {:binary, message}, socket) when is_binary(message) do
    handle_in("yjs_sync", message, socket)
  end

  def handle_in("yjs_sync", message, socket) when is_binary(message) do
    case Sync.message_decode(message) do
      {:ok, {:sync, {:sync_step1, _state_vector}}} ->
        :ok = SharedDoc.start_sync(socket.assigns.shared_doc, message)
        {:noreply, socket}

      _message ->
        {:reply, {:error, %{reason: "invalid sync request"}}, socket}
    end
  end

  def handle_in("yjs", {:binary, message}, socket) when is_binary(message) do
    handle_in("yjs", message, socket)
  end

  def handle_in("yjs", message, socket) when is_binary(message) do
    if socket.assigns.can_edit_pages? or !Collaboration.document_update?(message) do
      current_user = socket.assigns.scope.current_user

      :ok = SharedDoc.send_yjs_message(socket.assigns.shared_doc, message)
      :ok = Collaboration.record_update(socket.assigns.room, current_user.id, message)

      {:noreply, socket}
    else
      {:reply, {:error, %{reason: "editing not permitted"}}, socket}
    end
  end

  def handle_in("confirm_updates_applied", _payload, socket) do
    _doc = SharedDoc.get_doc(socket.assigns.shared_doc)
    {:reply, {:ok, %{}}, socket}
  end

  @impl true
  def handle_info({:yjs, message, shared_doc}, %{assigns: %{shared_doc: shared_doc}} = socket) do
    push(socket, "yjs", {:binary, message})
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, %{assigns: %{shared_doc: shared_doc}}) do
    if Process.alive?(shared_doc) do
      Collaboration.close_document(shared_doc)
    end

    :ok
  end

  def terminate(_reason, _socket), do: :ok
end
