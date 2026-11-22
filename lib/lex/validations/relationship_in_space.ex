defmodule Lex.Validations.RelationshipInSpace do
  use Ash.Resource.Validation

  @impl true
  def init(options) do
    if is_atom(options[:relationship]) do
      {:ok, options}
    else
      {:error, "relationship must be an atom"}
    end
  end

  @impl true
  def validate(changeset, options, _context) do
    relationship = Ash.Resource.Info.relationship(changeset.resource, options[:relationship])
    related_id = Ash.Changeset.get_attribute(changeset, relationship.source_attribute)

    validate_relationship(relationship, related_id, changeset.tenant)
  end

  defp validate_relationship(_relationship, nil, _tenant), do: :ok

  defp validate_relationship(relationship, related_id, tenant) do
    relationship.destination
    |> Ash.get(related_id,
      authorize?: false,
      not_found_error?: false,
      tenant: tenant
    )
    |> case do
      {:ok, nil} ->
        {:error, field: relationship.source_attribute, message: "does not belong to this space"}

      {:ok, _record} ->
        :ok

      {:error, error} ->
        {:error, error}
    end
  end
end
