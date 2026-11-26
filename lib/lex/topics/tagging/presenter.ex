defmodule Lex.Topics.Tagging.Presenter do
  alias Lex.Topics.Tagging

  def present(taggings, sorting, subject \\ :topic) do
    {group_key, label} =
      case subject do
        :topic -> {:topic_id, & &1.topic.name}
        :tagged_membership -> {:taggable_id, & &1.tagged_membership.display_name}
      end

    taggings
    |> group(group_key, subject)
    |> sort(sorting, label)
  end

  defp group(taggings, group_key, subject) do
    taggings
    |> Enum.group_by(&Map.fetch!(&1, group_key))
    |> Enum.map(fn {id, [first | _rest] = group_taggings} ->
      self_assessment = group_taggings |> Enum.find(&Tagging.self_assessment?/1)

      endorsements =
        group_taggings
        |> Enum.filter(&Tagging.endorsement?/1)
        |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})

      %{
        subject => Map.fetch!(first, subject),
        endorsements: endorsements,
        self_assessment: self_assessment,
        id: id
      }
    end)
  end

  defp sort(groups, %{by: :alpha, direction: direction}, label) do
    Enum.sort_by(groups, &name_key(&1, label), direction)
  end

  defp sort(groups, %{by: dimension, direction: direction}, label) do
    key = Atom.to_string(dimension)

    Enum.sort_by(groups, fn group ->
      level = dimension_level(group, key)
      level = if direction == :desc, do: -level, else: level
      {level, name_key(group, label)}
    end)
  end

  defp name_key(group, label), do: {String.downcase(label.(group)), group.id}

  defp dimension_level(%{self_assessment: nil}, _dimension), do: 0

  defp dimension_level(group, dimension) do
    group.self_assessment.dimensions |> Map.get(dimension, 0)
  end
end
