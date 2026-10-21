defmodule LexWeb.CollaborationChannelTest do
  use ExUnit.Case, async: true

  import Phoenix.ChannelTest

  alias Lex.Collaboration
  alias Yex.Sync

  @endpoint LexWeb.Endpoint

  test "clients in one room share a document without leaking updates to another room" do
    room = unique_room()
    other_room = unique_room()

    first_socket = join(room)
    second_socket = join(room)
    _other_socket = join(other_room)

    assert {:ok, shared_doc} = Collaboration.open_document(room)
    assert {:ok, ^shared_doc} = Collaboration.open_document(room)
    assert {:ok, other_shared_doc} = Collaboration.open_document(other_room)
    refute shared_doc == other_shared_doc

    push(first_socket, "yjs_sync", {:binary, sync_step1_message()})
    assert_push "yjs", {:binary, sync_reply}
    assert {:ok, {:sync, {:sync_step2, _update}}} = Sync.message_decode(sync_reply)
    assert_push "yjs", {:binary, server_sync_step1}
    assert {:ok, {:sync, {:sync_step1, _state_vector}}} = Sync.message_decode(server_sync_step1)
    assert_push "yjs", {:binary, awareness_reply}
    assert {:ok, {:awareness, _awareness}} = Sync.message_decode(awareness_reply)

    update_message = document_update_message("shared text")
    push(first_socket, "yjs", {:binary, update_message})

    assert_push "yjs", {:binary, received_message}
    assert Sync.message_decode(received_message) == Sync.message_decode(update_message)
    refute_push "yjs", _message, 50

    push(second_socket, "yjs_sync", {:binary, sync_step1_message()})
    assert_push "yjs", {:binary, second_sync_reply}

    assert {:ok, {:sync, {:sync_step2, update}}} =
             Sync.message_decode(second_sync_reply)

    synced_doc = Yex.Doc.new()
    assert :ok = Yex.apply_update(synced_doc, update)
    assert Yex.Doc.get_text(synced_doc, "content") |> Yex.Text.to_string() == "shared text"
  end

  test "a document exits only after its final observing channel closes" do
    room = unique_room()
    first_socket = join(room)
    second_socket = join(room)
    {:ok, shared_doc} = Collaboration.open_document(room)
    monitor = Process.monitor(shared_doc)

    close_channel(first_socket)
    assert Process.alive?(shared_doc)
    assert {:ok, ^shared_doc} = Collaboration.open_document(room)

    close_channel(second_socket)
    assert_receive {:DOWN, ^monitor, :process, ^shared_doc, :normal}
    assert Registry.lookup(Lex.Collaboration.Registry, room) == []
  end

  defp close_channel(socket) do
    Process.unlink(socket.channel_pid)
    :ok = close(socket)
  end

  defp document_update_message(text) do
    doc = Yex.Doc.new()
    doc |> Yex.Doc.get_text("content") |> Yex.Text.insert(0, text)
    {:ok, update} = Yex.encode_state_as_update(doc)
    Sync.message_encode!({:sync, {:sync_update, update}})
  end

  defp join(room) do
    LexWeb.CollaborationSocket
    |> socket(nil, %{})
    |> subscribe_and_join!(LexWeb.CollaborationChannel, "y_doc:#{room}")
  end

  defp sync_step1_message do
    doc = Yex.Doc.new()
    {:ok, step1} = Sync.get_sync_step1(doc)
    Sync.message_encode!({:sync, step1})
  end

  defp unique_room do
    "playground/test-#{System.unique_integer([:positive])}"
  end
end
