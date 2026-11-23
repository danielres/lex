defmodule Lex.Topics.Tagging.Presenter do
  alias Lex.Topics.Tagging

  def present(taggings, sorting) do
    taggings
    |> group_by_topic()
    |> sort(sorting)
  end

  defp group_by_topic(taggings) do
    taggings_by_topic = Enum.group_by(taggings, & &1.topic_id)

    taggings_by_topic
    |> Enum.map(fn {_topic_id, topic_taggings} ->
      [first | _rest] = topic_taggings

      self_assessment = topic_taggings |> Enum.find(&Tagging.self_assessment?/1)

      endorsements =
        topic_taggings
        |> Enum.filter(&Tagging.endorsement?/1)
        |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

      %{
        endorsements: endorsements,
        self_assessment: self_assessment,
        topic: first.topic
      }
    end)
  end

  defp sort(groups, %{by: :alpha, direction: direction}) do
    groups |> Enum.sort_by(&String.downcase(&1.topic.name), direction)
  end

  defp sort(groups, %{by: dimension, direction: direction}) do
    groups |> sort_by_dimension(Atom.to_string(dimension), direction)
  end

  defp sort_by_dimension(groups, dimension, direction) do
    Enum.sort(groups, fn left, right ->
      left_level = left |> dimension_level(dimension)
      right_level = right |> dimension_level(dimension)

      if left_level == right_level do
        l_name = left.topic.name |> String.downcase()
        r_name = right.topic.name |> String.downcase()
        l_name <= r_name
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
    group.self_assessment.dimensions |> Map.get(dimension, 0)
  end
end
