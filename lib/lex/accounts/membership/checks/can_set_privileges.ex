defmodule Lex.Accounts.Membership.Checks.CanSetPrivileges do
  use Ash.Policy.SimpleCheck

  alias Lex.Accounts.Membership.Access

  @impl true
  def describe(_options), do: "actor can change the membership's privileges"

  @impl true
  def match?(nil, _context, _options), do: {:ok, false}

  def match?(actor, %{subject: %{data: membership}}, _options) do
    if membership.user_id == actor.id do
      {:ok, false}
    else
      membership.user_id
      |> Access.check_owner(membership.space_id)
      |> case do
        {:ok, true} ->
          {:ok, false}

        {:ok, false} ->
          actor.id |> Access.check_privilege(membership.space_id, :manage_privileges)

        {:error, error} ->
          {:error, error}
      end
    end
  end
end
