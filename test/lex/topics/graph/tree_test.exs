defmodule Lex.Topics.Graph.TreeTest do
  use ExUnit.Case, async: true

  alias Lex.Topics.Graph

  test "builds and sorts the topic tree" do
    topics = [topic("c"), topic("b"), topic("a")]
    children = %{"a" => ["c"]}

    tree = Graph.tree(topics, children)
    [first_root, second_root] = tree

    assert first_root.topic.id == "a"
    assert second_root.topic.id == "b"
    assert Enum.map(first_root.children, & &1.topic.id) == ["c"]
  end

  test "focuses the tree on a topic and its ancestors" do
    topics = [topic("a"), topic("b"), topic("c"), topic("d")]
    children = %{"a" => ["b"], "b" => ["c"]}
    tree = Graph.tree(topics, children)

    assert [a] = Graph.focus(tree, "c")
    assert [b] = a.children
    assert [c] = b.children
    assert c.topic.id == "c"
    assert Graph.focus(tree, "missing") == []
    assert Graph.focus(tree, nil) == tree
  end

  test "detects cycles" do
    topics = [topic("a"), topic("b")]
    children = %{"a" => ["b"], "b" => ["a"]}

    assert_raise ArgumentError, ~r/cycle/, fn ->
      Graph.tree(topics, children)
    end
  end

  defp topic(id), do: %{id: id, name: String.upcase(id)}
end
