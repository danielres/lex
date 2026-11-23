defmodule Lex.Topics.Graph.Tree do
  def build(topics, children) do
    topics_by_id = Map.new(topics, &{&1.id, &1})

    child_ids =
      children
      |> Map.values()
      |> List.flatten()
      |> MapSet.new()

    tree =
      topics
      |> Enum.reject(&MapSet.member?(child_ids, &1.id))
      |> Enum.map(fn topic ->
        build_node(topic.id, nil, [], MapSet.new(), topics_by_id, children)
      end)
      |> sort_nodes()

    rendered_ids = tree |> collect_topic_ids() |> MapSet.new()
    topic_ids = topics |> Enum.map(& &1.id) |> MapSet.new()

    if rendered_ids == topic_ids do
      tree
    else
      raise ArgumentError, "topic graph contains a cycle or dangling topic reference"
    end
  end

  def focus(nodes, topic_id) when topic_id in [nil, ""], do: nodes

  def focus(nodes, topic_id) do
    Enum.flat_map(nodes, &focus_node(&1, topic_id))
  end

  defp build_node(topic_id, parent_id, path, visited, topics, children) do
    if MapSet.member?(visited, topic_id) do
      raise ArgumentError, "cycle detected in topic graph at #{topic_id}"
    end

    topic = Map.fetch!(topics, topic_id)
    path = path ++ [topic_id]
    visited = MapSet.put(visited, topic_id)

    descendants =
      children
      |> Map.get(topic_id, [])
      |> Enum.map(&build_node(&1, topic_id, path, visited, topics, children))
      |> sort_nodes()

    %{
      children: descendants,
      dom_id: "topic-#{Enum.join(path, "-")}",
      parent_id: parent_id,
      path: path,
      topic: topic
    }
  end

  defp sort_nodes(nodes) do
    Enum.sort_by(nodes, &String.downcase(&1.topic.name))
  end

  defp focus_node(node, topic_id) do
    if node.topic.id == topic_id do
      [node]
    else
      case focus(node.children, topic_id) do
        [] -> []
        children -> [%{node | children: children}]
      end
    end
  end

  defp collect_topic_ids(nodes) do
    Enum.flat_map(nodes, fn node ->
      [node.topic.id | collect_topic_ids(node.children)]
    end)
  end
end
