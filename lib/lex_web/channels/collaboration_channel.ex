defmodule LexWeb.CollaborationChannel do
  use LexWeb, :channel

  alias Lex.Collaboration
  alias Yex.Sync.SharedDoc

  @impl true
  def join("y_doc:" <> room, _payload, socket) when room != "" do
    with {:ok, shared_doc} <- Collaboration.open_document(room),
         :ok <- SharedDoc.observe(shared_doc) do
      {:ok, assign(socket, :shared_doc, shared_doc)}
    else
      {:error, reason} -> {:error, %{reason: inspect(reason)}}
    end
  end

  @impl true
  def handle_in("yjs_sync", {:binary, message}, socket) when is_binary(message) do
    handle_in("yjs_sync", message, socket)
  end

  def handle_in("yjs_sync", message, socket) when is_binary(message) do
    :ok = SharedDoc.start_sync(socket.assigns.shared_doc, message)
    {:noreply, socket}
  end

  def handle_in("yjs", {:binary, message}, socket) when is_binary(message) do
    handle_in("yjs", message, socket)
  end

  def handle_in("yjs", message, socket) when is_binary(message) do
    :ok = SharedDoc.send_yjs_message(socket.assigns.shared_doc, message)
    {:noreply, socket}
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
