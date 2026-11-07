defmodule Lex.Accounts.Space.Changes.CreateOwnerMembership do
  use Ash.Resource.Change

  alias Lex.Accounts.Membership

  @impl true
  def change(changeset, _options, %{actor: nil}) do
    Ash.Changeset.add_error(changeset, "an authenticated user is required")
  end

  def change(changeset, _options, %{actor: actor}) do
    Ash.Changeset.after_action(changeset, fn _changeset, space ->
      Membership
      |> Ash.Changeset.for_create(
        :invite,
        %{user_id: actor.id},
        actor: actor,
        authorize?: false,
        tenant: space.id
      )
      |> Ash.create()
      |> case do
        {:ok, _membership} -> {:ok, space}
        {:error, error} -> {:error, error}
      end
    end)
  end
end
