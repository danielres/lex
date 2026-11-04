defmodule Lex.ScopeTest do
  use ExUnit.Case, async: true

  alias Lex.Accounts.User

  test "provides the authenticated user as the actor without requiring a tenant" do
    current_user = %User{
      id: Ecto.UUID.generate(),
      display_name: "Tom",
      hue: 25
    }

    scope = %Lex.Scope{current_user: current_user}
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

    space_id = Ecto.UUID.generate()
    scope = %Lex.Scope{current_user: current_user, space_id: space_id}
    opts = Ash.Scope.to_opts(scope)

    assert opts[:actor] == current_user
    assert opts[:tenant] == space_id
  end
end
