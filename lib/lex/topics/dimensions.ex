defmodule Lex.Topics.Dimensions do
  @definitions %{
    "membership" => %{
      "interest" => %{
        color: "oklch(63% 0.13 358)",
        field: :interest,
        icon: "hero-heart-micro",
        key: "interest",
        label: "Interest",
        max: 10
      },
      "experience" => %{
        color: "oklch(65% 0.15 255)",
        field: :experience,
        icon: "hero-academic-cap-micro",
        key: "experience",
        label: "Experience",
        max: 10
      }
    }
  }

  def all_for(taggable_type) do
    @definitions
    |> Map.fetch!(taggable_type)
    |> Map.values()
    |> Enum.sort_by(& &1.key)
  end

  def get!(taggable_type, key) do
    @definitions
    |> Map.fetch!(taggable_type)
    |> Map.fetch!(key)
  end
end
