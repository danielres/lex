defmodule LexWeb.TopicsLive.Graph.Attachment do
  use LexWeb, :live_view
  use LiveDelegate, path: [:graph, :attachment]

  alias Lex.Topics.Graph

  def on_mount(_params, _session, socket) do
    reset(socket)
  end

  @impl true
  def handle_event("start", %{"child-id" => child_id} = params, socket) do
    graph = socket.assigns.graph
    source_parent_id = params["source-parent-id"]

    if Enum.any?(graph.topics, &(&1.id == child_id)) do
      if source_parent_id && child_id not in Map.get(graph.children, source_parent_id, []) do
        {:noreply, Toast.put_toast(socket, :error, graph_error(:stale_parent))}
      else
        mode = if source_parent_id, do: "move", else: "attach"

        {:noreply,
         delegate_assign(socket, %{child_id: child_id, source_parent_id: source_parent_id, mode: mode})}
      end
    else
      {:noreply, Toast.put_toast(socket, :error, "Topic not found")}
    end
  end

  def handle_event("cancel", _params, socket), do: {:noreply, reset(socket)}

  def handle_event("mode", %{"parent_mode" => mode}, socket) when mode in ["move", "attach"] do
    if socket.assigns.graph.attachment.source_parent_id do
      {:noreply, delegate_assign(socket, :mode, mode)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("mode", _params, socket), do: {:noreply, socket}

  def handle_event("choose_parent", %{"parent-id" => parent_id}, socket) do
    case socket.assigns.graph.attachment do
      %{child_id: nil} ->
        {:noreply, Toast.put_toast(socket, :error, "Choose a topic to attach")}

      %{child_id: child_id, source_parent_id: source, mode: "move"} ->
        result = Graph.move(source, parent_id, child_id, scope: socket.assigns.scope)
        finish(result, socket, "Topic moved")

      %{child_id: child_id} ->
        result = Graph.attach(parent_id, child_id, scope: socket.assigns.scope)
        finish(result, socket, "Topic attached")
    end
  end

  defp reset(socket) do
    delegate_assign(socket, %{child_id: nil, source_parent_id: nil, mode: "attach"})
  end

  defp finish({:ok, _graph}, socket, message) do
    {:noreply, socket |> reset() |> Toast.put_toast(:info, message)}
  end

  defp finish({:error, reason}, socket, _message) do
    {:noreply, Toast.put_toast(socket, :error, graph_error(reason))}
  end

  defp graph_error(:stale_parent), do: "This parent link no longer exists"
  defp graph_error(:cycle), do: "That would create a cycle"
  defp graph_error(:invalid_topics), do: "Topics must belong to this space"
  defp graph_error(:self_link), do: "A topic cannot be its own child"
  defp graph_error(_error), do: "Could not update topic graph"
end
