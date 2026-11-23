defmodule Lex.Topics.Graph.Topology do
  def attach(children, parent_id, child_id) do
    case attachment_error(children, parent_id, child_id) do
      nil ->
        direct_children = Map.get(children, parent_id, [])
        {:ok, Map.put(children, parent_id, direct_children ++ [child_id])}

      :duplicate ->
        {:ok, children}

      error ->
        {:error, error}
    end
  end

  def detach(children, parent_id, child_id) do
    case Map.get(children, parent_id, []) |> Enum.reject(&(&1 == child_id)) do
      [] -> Map.delete(children, parent_id)
      child_ids -> Map.put(children, parent_id, child_ids)
    end
  end

  def normalize_children(topics, children) do
    topic_ids = topics |> MapSet.new(& &1.id)

    Enum.reduce(children, %{}, fn {parent_id, child_ids}, normalized ->
      if MapSet.member?(topic_ids, parent_id) do
        child_ids =
          child_ids
          |> Enum.flat_map(&resolve_child_ids(&1, topic_ids, children, MapSet.new()))
          |> Enum.uniq()

        case child_ids do
          [] -> normalized
          child_ids -> Map.put(normalized, parent_id, child_ids)
        end
      else
        normalized
      end
    end)
  end

  def parent_candidates(topics, children, child_id) do
    topics
    |> Enum.filter(&is_nil(attachment_error(children, &1.id, child_id)))
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  def remove_topic(children, topic_id) do
    children
    |> Map.delete(topic_id)
    |> Enum.reduce(%{}, fn {parent_id, child_ids}, result ->
      case Enum.reject(child_ids, &(&1 == topic_id)) do
        [] -> result
        remaining -> Map.put(result, parent_id, remaining)
      end
    end)
  end

  defp attachment_error(children, parent_id, child_id) do
    cond do
      parent_id == child_id -> :self_link
      child_id in Map.get(children, parent_id, []) -> :duplicate
      reachable?(children, child_id, parent_id, MapSet.new()) -> :cycle
      true -> nil
    end
  end

  defp resolve_child_ids(topic_id, topic_ids, children, visited) do
    cond do
      MapSet.member?(topic_ids, topic_id) ->
        [topic_id]

      MapSet.member?(visited, topic_id) ->
        raise ArgumentError, "cycle detected in topic graph at #{topic_id}"

      true ->
        visited = MapSet.put(visited, topic_id)

        children
        |> Map.get(topic_id, [])
        |> Enum.flat_map(&resolve_child_ids(&1, topic_ids, children, visited))
    end
  end

  defp reachable?(_children, node_id, node_id, _visited), do: true

  defp reachable?(children, node_id, target_id, visited) do
    if MapSet.member?(visited, node_id) do
      false
    else
      visited = MapSet.put(visited, node_id)

      children
      |> Map.get(node_id, [])
      |> Enum.any?(&reachable?(children, &1, target_id, visited))
    end
  end
end
