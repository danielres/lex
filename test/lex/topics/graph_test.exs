defmodule Lex.Topics.GraphTest do
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

  test "promotes children of a missing root to roots" do
    topics = [topic("c"), topic("d")]
    children = %{"b" => ["c", "d"]}

    normalized = Graph.normalize_children(topics, children)
    tree = Graph.tree(topics, normalized)

    assert normalized == %{}
    assert Enum.map(tree, & &1.topic.id) == ["c", "d"]
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

  test "leaves valid graphs unchanged and preserves cycle detection" do
    topics = [topic("a"), topic("b")]
    children = %{"a" => ["b"]}

    assert Graph.normalize_children(topics, children) == children

    cyclic_children = %{"a" => ["b"], "b" => ["a"]}

    assert Graph.normalize_children(topics, cyclic_children) == cyclic_children

    assert_raise ArgumentError, ~r/cycle/, fn ->
      Graph.tree(topics, cyclic_children)
    end
  end

  defp topic(id), do: %{id: id, name: String.upcase(id)}
end
