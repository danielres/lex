defmodule LexWeb.TopicsLive.Graph.Attachment do
  use LexWeb, :live_view
  use LiveDelegate, path: [:graph, :attachment]

  alias Lex.Topics.Graph

  def on_mount(_params, _session, socket) do
    delegate_assign(socket, %{child_id: nil})
  end

  @impl true
  def handle_event("start", %{"child-id" => child_id}, socket) do
    if Enum.any?(socket.assigns.graph.topics, &(&1.id == child_id)) do
      {:noreply, delegate_assign(socket, :child_id, child_id)}
    else
      {:noreply, Toast.put_toast(socket, :error, "Topic not found")}
    end
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, delegate_assign(socket, :child_id, nil)}
  end

  def handle_event("choose_parent", %{"parent-id" => parent_id}, socket) do
    child_id = socket.assigns.graph.attachment.child_id

    if child_id do
      attach(parent_id, child_id, socket)
    else
      {:noreply, Toast.put_toast(socket, :error, "Choose a topic to attach")}
    end
  end

  defp attach(parent_id, child_id, socket) do
    case Graph.attach(parent_id, child_id, scope: socket.assigns.scope) do
      {:ok, _graph} ->
        socket =
          socket
          |> delegate_assign(:child_id, nil)
          |> Toast.put_toast(:info, "Topic attached")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, Toast.put_toast(socket, :error, graph_error(reason))}
    end
  end

  defp graph_error(:cycle), do: "That would create a cycle"
  defp graph_error(:invalid_topics), do: "Topics must belong to this space"
  defp graph_error(:self_link), do: "A topic cannot be its own child"
  defp graph_error(_error), do: "Could not update topic graph"
end
