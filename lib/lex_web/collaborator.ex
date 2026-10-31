defmodule LexWeb.Collaborator do
  @behaviour Plug

  import Phoenix.Component, only: [assign: 3]
  import Plug.Conn, only: [get_session: 2, put_session: 3]

  @adjectives ~w(Bright Calm Curious Kind Swift)
  @animals ~w(Badger Fox Heron Otter Wren)
  @session_key :collaborator

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case get_session(conn, @session_key) do
      nil -> put_session(conn, @session_key, new())
      _collaborator -> conn
    end
  end

  def live_session(conn) do
    %{"collaborator" => get_session(conn, @session_key)}
  end

  def on_mount(:default, _params, %{"collaborator" => collaborator}, socket) do
    {:cont, assign(socket, :collaborator, collaborator)}
  end

  defp new do
    %{
      display_name: "#{Enum.random(@adjectives)} #{Enum.random(@animals)}",
      hue: Enum.random(0..359)
    }
  end
end
