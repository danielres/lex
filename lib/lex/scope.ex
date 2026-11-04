defmodule Lex.Scope do
  @enforce_keys [:current_user]
  defstruct [:current_user, :space_id]

  defimpl Ash.Scope.ToOpts do
    def get_actor(%{current_user: current_user}), do: {:ok, current_user}
    def get_authorize?(_scope), do: :error
    def get_context(_scope), do: :error
    def get_tenant(%{space_id: nil}), do: :error
    def get_tenant(%{space_id: space_id}), do: {:ok, space_id}
    def get_tracer(_scope), do: :error
  end
end
