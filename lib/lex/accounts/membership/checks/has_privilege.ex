defmodule Lex.Accounts.Membership.Checks.HasPrivilege do
  use Ash.Policy.SimpleCheck

  alias Lex.Accounts.Membership.Access

  @impl true
  def describe(options), do: "actor has the #{options[:privilege]} privilege"

  @impl true
  def match?(nil, _context, _options), do: {:ok, false}

  def match?(actor, context, options) do
    with {:ok, space_id} <- Ash.Scope.ToOpts.get_tenant(context) do
      actor.id |> Access.check_privilege(space_id, options[:privilege])
    end
  end
end
