defmodule Lex.Topics.Tagging.Presenter do
  alias Lex.Accounts.Membership

  def present(taggings, target, sorting) do
    taggings
    |> group_by_topic(target)
    |> sort(sorting)
  end

  defp group_by_topic(taggings, target) do
    taggings
    |> Enum.filter(fn tagging ->
      tagging.tagged_by_membership_id == target.id or
        is_struct(tagging.tagged_by_membership, Membership)
    end)
    |> Enum.group_by(& &1.topic_id)
    |> Enum.map(fn {_topic_id, [first | _rest] = topic_taggings} ->
      %{
        endorsements:
          topic_taggings
          |> Enum.reject(&(&1.tagged_by_membership_id == target.id))
          |> Enum.sort_by(&String.downcase(&1.tagged_by_membership.display_name)),
        self_assessment: Enum.find(topic_taggings, &(&1.tagged_by_membership_id == target.id)),
        topic: first.topic
      }
    end)
  end

  defp sort(groups, %{by: :alpha, direction: direction}) do
    Enum.sort_by(groups, &topic_name/1, direction)
  end

  defp sort(groups, %{by: dimension, direction: direction}) do
    sort_by_dimension(groups, Atom.to_string(dimension), direction)
  end

  defp sort_by_dimension(groups, dimension, direction) do
    Enum.sort(groups, fn left, right ->
      left_level = dimension_level(left, dimension)
      right_level = dimension_level(right, dimension)

      if left_level == right_level do
        topic_name(left) <= topic_name(right)
      else
        case direction do
          :asc -> left_level < right_level
          :desc -> left_level > right_level
        end
      end
    end)
  end

  defp dimension_level(%{self_assessment: nil}, _dimension), do: 0

  defp dimension_level(group, dimension) do
    Map.get(group.self_assessment.dimensions, dimension, 0)
  end

  defp topic_name(group), do: String.downcase(group.topic.name)
end
