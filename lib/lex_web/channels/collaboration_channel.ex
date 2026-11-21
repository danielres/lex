defmodule LexWeb.CollaborationChannel do
  use LexWeb, :channel

  require Logger

  alias Ash.Notifier.Notification
  alias Lex.Accounts.Membership
  alias Lex.Accounts.Membership.Access
  alias Lex.Collaboration
  alias Yex.Sync
  alias Yex.Sync.SharedDoc

  @membership_retry_interval 2_000

  @impl true
  def join("y_doc:" <> room, _payload, socket) when room != "" do
    with :ok <- Membership.subscribe(socket.assigns.scope),
         {:ok, shared_doc} <- Collaboration.open_document(socket.assigns.scope, room),
         :ok <- SharedDoc.observe(shared_doc) do
      socket =
        socket
        |> assign(:membership_retry_timer, nil)
        |> assign(:membership_status, :active)
        |> assign(:room, room)
        |> assign(:shared_doc, shared_doc)

      {:ok, socket}
    else
      {:error, reason} -> {:error, %{reason: inspect(reason)}}
    end
  end

  @impl true
  def handle_in(
        event,
        _payload,
        %{assigns: %{membership_status: :unavailable}} = socket
      )
      when event in ["yjs_sync", "yjs", "confirm_updates_applied"] do
    reject_membership_unavailable(socket)
  end

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
      {:unavailable, socket} -> reject_membership_unavailable(socket)
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
      {:unavailable, socket} -> reject_membership_unavailable(socket)
    end
  end

  def handle_in("confirm_updates_applied", _payload, socket) do
    with {:ok, socket} <- refresh_scope(socket) do
      _doc = SharedDoc.get_doc(socket.assigns.shared_doc)
      {:reply, {:ok, %{}}, socket}
    else
      :inactive -> stop_inactive(socket)
      {:unavailable, socket} -> reject_membership_unavailable(socket)
    end
  end

  @impl true
  def handle_info(
        {:yjs, message, shared_doc},
        %{assigns: %{membership_status: :active, shared_doc: shared_doc}} = socket
      ) do
    push(socket, "yjs", {:binary, message})
    {:noreply, socket}
  end

  def handle_info(
        {:yjs, _message, shared_doc},
        %{assigns: %{membership_status: :unavailable, shared_doc: shared_doc}} = socket
      ) do
    {:noreply, socket}
  end

  def handle_info(%Notification{resource: Membership}, socket) do
    case refresh_scope(socket) do
      {:ok, socket} -> {:noreply, socket}
      :inactive -> {:stop, :normal, socket}
      {:unavailable, socket} -> {:noreply, socket}
    end
  end

  def handle_info(:retry_membership, socket) do
    socket = socket |> assign(:membership_retry_timer, nil)

    case refresh_scope(socket) do
      {:ok, socket} -> {:noreply, socket}
      :inactive -> {:stop, :normal, socket}
      {:unavailable, socket} -> {:noreply, socket}
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
        recovering? = socket.assigns.membership_status == :unavailable
        scope = %{scope | membership: membership}

        socket =
          socket
          |> cancel_membership_retry()
          |> assign(:membership_status, :active)
          |> assign(:scope, scope)

        if recovering? do
          :ok = push(socket, "yjs_resync", %{})
        end

        {:ok, socket}

      {:ok, _membership} ->
        :inactive

      {:error, error} ->
        socket = socket |> mark_membership_unavailable(error)
        {:unavailable, socket}
    end
  end

  defp mark_membership_unavailable(socket, error) do
    if socket.assigns.membership_status == :active do
      Logger.warning(
        "Could not verify collaboration membership for room #{inspect(socket.assigns.room)}: #{inspect(error)}"
      )
    end

    socket
    |> assign(:membership_status, :unavailable)
    |> schedule_membership_retry()
  end

  defp reject_membership_unavailable(socket) do
    {:reply, {:error, %{reason: "membership verification unavailable"}}, socket}
  end

  defp schedule_membership_retry(%{assigns: %{membership_retry_timer: nil}} = socket) do
    timer = Process.send_after(self(), :retry_membership, @membership_retry_interval)
    socket |> assign(:membership_retry_timer, timer)
  end

  defp schedule_membership_retry(socket), do: socket

  defp cancel_membership_retry(%{assigns: %{membership_retry_timer: nil}} = socket),
    do: socket

  defp cancel_membership_retry(socket) do
    Process.cancel_timer(socket.assigns.membership_retry_timer)
    socket |> assign(:membership_retry_timer, nil)
  end

  defp stop_inactive(socket) do
    {:stop, :normal, {:error, %{reason: "membership inactive"}}, socket}
  end
end
