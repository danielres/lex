defmodule LexWeb.CollaborationSocket do
  use Phoenix.Socket

  alias AshAuthentication.Plug.Helpers
  alias Lex.Accounts
  alias Lex.Accounts.Space
  alias Lex.Accounts.User

  channel "y_doc:*", LexWeb.CollaborationChannel

  @impl true
  def connect(%{"space_id" => space_id}, socket, %{session: session}) when is_map(session) do
    with {:ok, space_id} <- Ecto.UUID.cast(space_id),
         {:ok, current_user} <-
           Helpers.authenticate_resource_from_session(User, session, :lex, []),
         {:ok, space} <- Ash.get(Space, space_id, authorize?: false),
         scope = %Lex.Scope{space: space, user: current_user},
         {:ok, %{status: :active} = membership} <-
           Accounts.get_membership(scope) do
      scope = %{scope | membership: membership}
      can_edit_pages? = Accounts.has_privilege?(scope, :edit_pages)

      socket =
        socket
        |> assign(:can_edit_pages?, can_edit_pages?)
        |> assign(:scope, scope)

      {:ok, socket}
    else
      _error -> :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(_socket), do: nil
end
