defmodule Lex.Accounts.Membership.Access do
  require Ash.Query

  alias Lex.Accounts.Membership
  alias Lex.Accounts.Privilege
  alias Lex.Accounts.Space

  def available_privileges, do: Privilege.values()

  def effective_privileges(%Lex.Scope{
        user: %{id: user_id},
        membership: %Membership{
          status: :active,
          privileges: privileges,
          space_id: space_id,
          user_id: user_id
        },
        space: %Space{id: space_id, owner_id: owner_id}
      }) do
    if user_id == owner_id, do: Privilege.values(), else: privileges
  end

  def effective_privileges(_scope), do: []

  def can?(scope, privilege) do
    privilege in effective_privileges(scope)
  end

  def check_active_member(actor_id, space_id) do
    actor_id
    |> get_active_membership(space_id)
    |> case do
      {:ok, nil} -> {:ok, false}
      {:ok, %Membership{}} -> {:ok, true}
      {:error, error} -> {:error, error}
    end
  end

  def check_privilege(actor_id, space_id, privilege) do
    actor_id
    |> get_active_membership(space_id)
    |> case do
      {:ok, nil} ->
        {:ok, false}

      {:ok, membership} ->
        membership |> check_membership_privilege(space_id, privilege)

      {:error, error} ->
        {:error, error}
    end
  end

  def check_owner(user_id, space_id) do
    Space
    |> Ash.get(space_id, authorize?: false)
    |> case do
      {:ok, %{owner_id: ^user_id}} -> {:ok, true}
      {:ok, _space} -> {:ok, false}
      {:error, error} -> {:error, error}
    end
  end

  defp get_active_membership(user_id, space_id) do
    Membership
    |> Ash.Query.filter(user_id == ^user_id and status == :active)
    |> Ash.read_one(authorize?: false, tenant: space_id)
  end

  defp check_membership_privilege(membership, space_id, privilege) do
    membership.user_id
    |> check_owner(space_id)
    |> case do
      {:ok, true} -> {:ok, true}
      {:ok, false} -> {:ok, privilege in membership.privileges}
      {:error, error} -> {:error, error}
    end
  end
end
