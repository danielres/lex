defmodule Lex.Topics.Graph.TopologyTest do
  use ExUnit.Case, async: true

  alias Lex.Topics.Graph

  test "replaces a missing internal topic with its children" do
    topics = [topic("a"), topic("c"), topic("d")]
    children = %{"a" => ["b"], "b" => ["c", "d"]}

    assert Graph.normalize_children(topics, children) == %{"a" => ["c", "d"]}
  end

  test "promotes children under every parent of a missing topic" do
    topics = [topic("a"), topic("c"), topic("d"), topic("e")]
    children = %{"a" => ["b"], "e" => ["b"], "b" => ["c", "d"]}

    assert Graph.normalize_children(topics, children) == %{
             "a" => ["c", "d"],
             "e" => ["c", "d"]
           }
  end

  test "removes a missing root while preserving its children as roots" do
    topics = [topic("c"), topic("d")]
    children = %{"b" => ["c", "d"]}

    assert Graph.normalize_children(topics, children) == %{}
  end

  test "removes a missing leaf" do
    topics = [topic("a")]
    children = %{"a" => ["b"]}

    assert Graph.normalize_children(topics, children) == %{}
  end

  test "contracts chains of missing topics" do
    topics = [topic("a"), topic("d")]
    children = %{"a" => ["b"], "b" => ["c"], "c" => ["d"]}

    assert Graph.normalize_children(topics, children) == %{"a" => ["d"]}
  end

  test "deduplicates promoted children while preserving their order" do
    topics = [topic("a"), topic("c"), topic("d")]
    children = %{"a" => ["b", "c"], "b" => ["c", "d"]}

    assert Graph.normalize_children(topics, children) == %{"a" => ["c", "d"]}
  end

  test "expands shared missing subgraphs once for each surviving parent" do
    topics = [topic("left"), topic("right"), topic("leaf")]

    children =
      0..29
      |> Enum.reduce(%{}, fn layer, children ->
        descendants = if layer == 29, do: ["leaf"], else: missing_topic_ids(layer + 1)

        Enum.reduce(missing_topic_ids(layer), children, fn topic_id, children ->
          Map.put(children, topic_id, descendants)
        end)
      end)
      |> Map.put("left", missing_topic_ids(0))
      |> Map.put("right", missing_topic_ids(0))

    assert Graph.normalize_children(topics, children) == %{
             "left" => ["leaf"],
             "right" => ["leaf"]
           }
  end

  test "leaves valid graphs unchanged" do
    topics = [topic("a"), topic("b")]
    children = %{"a" => ["b"]}

    assert Graph.normalize_children(topics, children) == children
  end

  test "detects cycles between missing topics during normalization" do
    topics = [topic("a")]
    children = %{"a" => ["b"], "b" => ["c"], "c" => ["b"]}

    assert_raise ArgumentError, ~r/cycle/, fn ->
      Graph.normalize_children(topics, children)
    end
  end

  defp topic(id), do: %{id: id, name: String.upcase(id)}

  defp missing_topic_ids(layer) do
    ["missing-#{layer}-left", "missing-#{layer}-right"]
  end
end
