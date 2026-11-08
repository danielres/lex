defmodule Lex.ScopeTest do
  use ExUnit.Case, async: true

  alias Lex.Accounts.User

  test "provides the authenticated user as the actor without requiring a tenant" do
    current_user = %User{
      id: Ecto.UUID.generate(),
      display_name: "Tom",
      hue: 25
    }

    scope = %Lex.Scope{user: current_user}
    opts = Ash.Scope.to_opts(scope)

    assert opts[:actor] == current_user
    refute Keyword.has_key?(opts, :tenant)
  end

  test "provides the current space as the tenant" do
    current_user = %User{
      id: Ecto.UUID.generate(),
      display_name: "Sandra",
      hue: 115
    }

    membership = %{id: Ecto.UUID.generate()}
    space = %Lex.Accounts.Space{id: Ecto.UUID.generate()}

    scope = %Lex.Scope{
      membership: membership,
      space: space,
      user: current_user
    }

    opts = Ash.Scope.to_opts(scope)

    assert opts[:actor] == current_user
    assert opts[:tenant] == space.id
    assert scope.membership == membership
  end
end
