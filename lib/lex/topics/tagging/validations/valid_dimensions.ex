defmodule Lex.Topics.Tagging.Validations.ValidDimensions do
  use Ash.Resource.Validation

  alias Lex.Topics.Dimensions

  @impl true
  def validate(changeset, _options, _context) do
    dimensions = Ash.Changeset.get_attribute(changeset, :dimensions)

    allowed_dimensions =
      "membership"
      |> Dimensions.all_for()
      |> Map.new(&{&1.key, &1.max})

    valid? =
      is_map(dimensions) and
        Enum.all?(dimensions, fn {key, value} ->
          case Map.fetch(allowed_dimensions, key) do
            {:ok, maximum} -> is_integer(value) and value in 1..maximum
            :error -> false
          end
        end)

    if valid? do
      :ok
    else
      {:error,
       field: :dimensions,
       message: "must contain known dimensions with ratings within their allowed range"}
    end
  end
end
