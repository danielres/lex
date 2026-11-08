defmodule Lex.Scope do
  @enforce_keys [:user]
  defstruct [:membership, :space, :user]

  defimpl Ash.Scope.ToOpts do
    def get_actor(%{user: user}), do: {:ok, user}
    def get_authorize?(_scope), do: :error
    def get_context(_scope), do: :error
    def get_tenant(%{space: nil}), do: :error
    def get_tenant(%{space: %{id: space_id}}), do: {:ok, space_id}
    def get_tracer(_scope), do: :error
  end
end
