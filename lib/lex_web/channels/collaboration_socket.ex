defmodule LexWeb.CollaborationSocket do
  use Phoenix.Socket

  channel "y_doc:*", LexWeb.CollaborationChannel

  @impl true
  def connect(%{"space_id" => space_id}, socket, _connect_info) do
    case Ecto.UUID.cast(space_id) do
      {:ok, space_id} -> {:ok, assign(socket, :scope, %Lex.Scope{space_id: space_id})}
      :error -> :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(_socket), do: nil
end
