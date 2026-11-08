defmodule Lex.Accounts.Membership.Checks.ActiveMember do
  use Ash.Policy.SimpleCheck

  alias Lex.Accounts.Membership.Access

  @impl true
  def describe(_options), do: "actor is an active member"

  @impl true
  def match?(nil, _context, _options), do: {:ok, false}

  def match?(actor, context, _options) do
    with {:ok, space_id} <- Ash.Scope.ToOpts.get_tenant(context) do
      actor.id |> Access.check_active_member(space_id)
    end
  end
end
