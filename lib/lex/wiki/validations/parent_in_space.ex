defmodule Lex.Wiki.Validations.ParentInSpace do
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
  def validate(changeset, options, context) do
    relationship = Ash.Resource.Info.relationship(changeset.resource, options[:relationship])
    parent_id = Ash.Changeset.get_attribute(changeset, relationship.source_attribute)

    relationship.destination
    |> Ash.get(parent_id,
      authorize?: false,
      not_found_error?: false,
      tenant: context.tenant
    )
    |> case do
      {:ok, nil} ->
        {:error, field: relationship.source_attribute, message: "does not belong to this space"}

      {:ok, _parent} ->
        :ok

      {:error, error} ->
        {:error, error}
    end
  end
end
