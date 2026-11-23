defmodule Lex.Topics.Tagging.Presenter do
  alias Lex.Accounts.Membership
  alias Lex.Topics.Tagging

  def present(taggings, sorting) do
    taggings
    |> group_by_topic()
    |> sort(sorting)
  end

  defp group_by_topic(taggings) do
    taggings_with_active_authors =
      Enum.filter(taggings, fn tagging ->
        is_struct(tagging.tagged_by_membership, Membership)
      end)

    taggings_by_topic =
      Enum.group_by(taggings_with_active_authors, fn tagging ->
        tagging.topic_id
      end)

    Enum.map(taggings_by_topic, fn {_topic_id, topic_taggings} ->
      [first_tagging | _remaining_taggings] = topic_taggings

      self_assessment =
        Enum.find(topic_taggings, fn tagging ->
          Tagging.self_assessment?(tagging)
        end)

      endorsements =
        topic_taggings
        |> Enum.filter(fn tagging ->
          Tagging.endorsement?(tagging)
        end)
        |> Enum.sort_by(fn endorsement ->
          String.downcase(endorsement.tagged_by_membership.display_name)
        end)

      %{
        endorsements: endorsements,
        self_assessment: self_assessment,
        topic: first_tagging.topic
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
