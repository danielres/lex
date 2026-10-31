defmodule LexWeb.CollaboratorTest do
  use LexWeb.ConnCase, async: true

  alias LexWeb.Collaborator

  test "creates a collaborator for a new browser session", %{conn: conn} do
    conn =
      conn
      |> init_test_session(%{})
      |> Collaborator.call([])

    collaborator = get_session(conn, :collaborator)

    assert collaborator.display_name =~
             ~r/^(Bright|Calm|Curious|Kind|Swift) (Badger|Fox|Heron|Otter|Wren)$/

    assert collaborator.hue in 0..359
  end

  test "keeps the existing browser session collaborator", %{conn: conn} do
    collaborator = %{display_name: "Curious Heron", hue: 127}

    conn =
      conn
      |> init_test_session(%{collaborator: collaborator})
      |> Collaborator.call([])

    assert get_session(conn, :collaborator) == collaborator
  end

  test "assigns the browser session collaborator during LiveView mount" do
    collaborator = %{display_name: "Swift Wren", hue: 284}
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}

    assert {:cont, socket} =
             Collaborator.on_mount(
               :default,
               %{},
               %{"collaborator" => collaborator},
               socket
             )

    assert socket.assigns.collaborator == collaborator
  end
end
