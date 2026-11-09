defmodule LexWeb.CollaborationChannel do
  use LexWeb, :channel

  alias Ash.Notifier.Notification
  alias Lex.Accounts.Membership
  alias Lex.Accounts.Membership.Access
  alias Lex.Collaboration
  alias Yex.Sync
  alias Yex.Sync.SharedDoc

  @impl true
  def join("y_doc:" <> room, _payload, socket) when room != "" do
    with :ok <- Membership.subscribe(socket.assigns.scope),
         {:ok, shared_doc} <- Collaboration.open_document(socket.assigns.scope, room),
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
    with {:ok, socket} <- refresh_scope(socket) do
      case Sync.message_decode(message) do
        {:ok, {:sync, {:sync_step1, _state_vector}}} ->
          :ok = SharedDoc.start_sync(socket.assigns.shared_doc, message)
          {:noreply, socket}

        _message ->
          {:reply, {:error, %{reason: "invalid sync request"}}, socket}
      end
    else
      :inactive -> stop_inactive(socket)
    end
  end

  def handle_in("yjs", {:binary, message}, socket) when is_binary(message) do
    handle_in("yjs", message, socket)
  end

  def handle_in("yjs", message, socket) when is_binary(message) do
    with {:ok, socket} <- refresh_scope(socket) do
      if Access.can?(socket.assigns.scope, :edit_pages) or
           !Collaboration.document_update?(message) do
        user = socket.assigns.scope.user

        :ok = SharedDoc.send_yjs_message(socket.assigns.shared_doc, message)
        :ok = Collaboration.record_update(socket.assigns.room, user.id, message)

        {:noreply, socket}
      else
        {:reply, {:error, %{reason: "editing not permitted"}}, socket}
      end
    else
      :inactive -> stop_inactive(socket)
    end
  end

  def handle_in("confirm_updates_applied", _payload, socket) do
    with {:ok, socket} <- refresh_scope(socket) do
      _doc = SharedDoc.get_doc(socket.assigns.shared_doc)
      {:reply, {:ok, %{}}, socket}
    else
      :inactive -> stop_inactive(socket)
    end
  end

  @impl true
  def handle_info({:yjs, message, shared_doc}, %{assigns: %{shared_doc: shared_doc}} = socket) do
    push(socket, "yjs", {:binary, message})
    {:noreply, socket}
  end

  def handle_info(%Notification{resource: Membership}, socket) do
    case refresh_scope(socket) do
      {:ok, socket} -> {:noreply, socket}
      :inactive -> {:stop, :normal, socket}
    end
  end

  @impl true
  def terminate(_reason, %{assigns: %{shared_doc: shared_doc}}) do
    if Process.alive?(shared_doc) do
      Collaboration.close_document(shared_doc)
    end

    :ok
  end

  def terminate(_reason, _socket), do: :ok

  defp refresh_scope(socket) do
    scope = socket.assigns.scope

    scope
    |> Membership.get()
    |> case do
      {:ok, %{status: :active} = membership} ->
        scope = %{scope | membership: membership}
        {:ok, socket |> assign(:scope, scope)}

      {:ok, _membership} ->
        :inactive

      {:error, _error} ->
        :inactive
    end
  end

  defp stop_inactive(socket) do
    {:stop, :normal, {:error, %{reason: "membership inactive"}}, socket}
  end
end
