defmodule Lex.Accounts.Membership.Validations.OwnerMustRemainMember do
  use Ash.Resource.Validation

  alias Lex.Accounts.Space

  @impl true
  def validate(changeset, _options, _context) do
    membership = changeset.data

    Space
    |> Ash.get(membership.space_id, authorize?: false)
    |> case do
      {:ok, %{owner_id: owner_id}} when owner_id == membership.user_id ->
        {:error, field: :status, message: "the space owner must remain a member"}

      {:ok, _space} ->
        :ok

      {:error, error} ->
        {:error, error}
    end
  end
end
