defmodule Lex.Topics.Tagging.Presenter do
  alias Lex.Topics.Tagging

  def present(taggings, sorting) do
    taggings
    |> group_by_topic()
    |> sort(sorting)
  end

  defp group_by_topic(taggings) do
    taggings_by_topic = Enum.group_by(taggings, & &1.topic_id)

    Enum.map(taggings_by_topic, fn {_topic_id, topic_taggings} ->
      [first_tagging | _remaining_taggings] = topic_taggings

      self_assessment = topic_taggings |> Enum.find(&Tagging.self_assessment?/1)

      endorsements =
        topic_taggings
        |> Enum.filter(&Tagging.endorsement?/1)
        |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

      %{
        endorsements: endorsements,
        self_assessment: self_assessment,
        topic: first_tagging.topic
      }
    end)
  end

  defp sort(groups, %{by: :alpha, direction: direction}) do
    Enum.sort_by(groups, &String.downcase(&1.topic.name), direction)
  end

  defp sort(groups, %{by: dimension, direction: direction}) do
    sort_by_dimension(groups, Atom.to_string(dimension), direction)
  end

  defp sort_by_dimension(groups, dimension, direction) do
    Enum.sort(groups, fn left, right ->
      left_level = dimension_level(left, dimension)
      right_level = dimension_level(right, dimension)

      if left_level == right_level do
        String.downcase(left.topic.name) <= String.downcase(right.topic.name)
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
end
