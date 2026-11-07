defmodule LexWeb.CollaborationSocket do
  use Phoenix.Socket

  alias AshAuthentication.Plug.Helpers
  alias Lex.Accounts
  alias Lex.Accounts.User

  channel "y_doc:*", LexWeb.CollaborationChannel

  @impl true
  def connect(%{"space_id" => space_id}, socket, %{session: session}) when is_map(session) do
    with {:ok, space_id} <- Ecto.UUID.cast(space_id),
         {:ok, current_user} <-
           Helpers.authenticate_resource_from_session(User, session, :lex, []),
         scope = %Lex.Scope{current_user: current_user, space_id: space_id},
         {:ok, %{status: :active} = membership} <-
           Accounts.get_membership(scope, current_user) do
      scope = %{scope | current_membership: membership}
      {:ok, assign(socket, :scope, scope)}
    else
      _error -> :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(_socket), do: nil
end
