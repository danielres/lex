defmodule LexWeb.CollaborationSocket do
  use Phoenix.Socket

  channel "y_doc:*", LexWeb.CollaborationChannel

  @impl true
  def connect(_params, socket, _connect_info), do: {:ok, socket}

  @impl true
  def id(_socket), do: nil
end
