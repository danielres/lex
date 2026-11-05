defmodule LexWeb.CollaborationChannelTest do
  use Lex.DataCase

  import Phoenix.ChannelTest

  require Ash.Query

  alias Lex.Collaboration
  alias Lex.Wiki.Page
  alias Lex.Wiki.PageDocument
  alias Lex.Wiki.PageRevision
  alias Yex.Sync
  alias Yex.Sync.SharedDoc

  @endpoint LexWeb.Endpoint

  setup do
    {:ok, scope: create_scope()}
  end

  test "clients in one room share a document without leaking updates to another room", %{
    scope: scope
  } do
    room = unique_room(scope)
    other_room = unique_room(scope)

    first_socket = scope |> join_channel(room)
    second_socket = scope |> join_channel(room)
    other_socket = scope |> join_channel(other_room)

    assert {:ok, shared_doc} = scope |> Collaboration.open_document(room)
    assert {:ok, ^shared_doc} = scope |> Collaboration.open_document(room)
    assert {:ok, other_shared_doc} = scope |> Collaboration.open_document(other_room)
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

    shared_doc_monitor = Process.monitor(shared_doc)
    other_shared_doc_monitor = Process.monitor(other_shared_doc)
    close_channel(first_socket)
    close_channel(second_socket)
    close_channel(other_socket)
    assert_receive {:DOWN, ^shared_doc_monitor, :process, ^shared_doc, :normal}
    assert_receive {:DOWN, ^other_shared_doc_monitor, :process, ^other_shared_doc, :normal}
  end

  test "a document exits only after its final observing channel closes", %{scope: scope} do
    room = unique_room(scope)
    first_socket = scope |> join_channel(room)
    second_socket = scope |> join_channel(room)
    {:ok, shared_doc} = scope |> Collaboration.open_document(room)
    monitor = Process.monitor(shared_doc)

    push(first_socket, "yjs", {:binary, document_update_message("checkpoint text")})
    close_channel(first_socket)
    assert Process.alive?(shared_doc)
    assert {:ok, ^shared_doc} = scope |> Collaboration.open_document(room)
    assert checkpoint_count(room) == 0

    close_channel(second_socket)
    assert_receive {:DOWN, ^monitor, :process, ^shared_doc, :normal}
    assert_eventually(fn -> Registry.lookup(Lex.Collaboration.Registry, room) == [] end)
    assert checkpoint_count(room) == 1
    assert scope |> persisted_text(room) == "checkpoint text"
    assert Ash.read!(PageRevision) == []
  end

  test "a checkpoint hydrates the document when its room reopens", %{scope: scope} do
    room = unique_room(scope)
    socket = scope |> join_channel(room)
    {:ok, shared_doc} = scope |> Collaboration.open_document(room)
    monitor = Process.monitor(shared_doc)

    push(socket, "yjs", {:binary, document_update_message("persistent text")})
    close_channel(socket)
    assert_receive {:DOWN, ^monitor, :process, ^shared_doc, :normal}

    reopened_socket = scope |> join_channel(room)
    push(reopened_socket, "yjs_sync", {:binary, sync_step1_message()})
    assert_push "yjs", {:binary, sync_reply}
    assert {:ok, {:sync, {:sync_step2, update}}} = Sync.message_decode(sync_reply)

    synced_doc = Yex.Doc.new()
    assert :ok = Yex.apply_update(synced_doc, update)
    assert Yex.Doc.get_text(synced_doc, "content") |> Yex.Text.to_string() == "persistent text"

    {:ok, reopened_shared_doc} = scope |> Collaboration.open_document(room)
    reopened_monitor = Process.monitor(reopened_shared_doc)
    close_channel(reopened_socket)
    assert_receive {:DOWN, ^reopened_monitor, :process, ^reopened_shared_doc, :normal}
  end

  test "nested documents checkpoint independently", %{scope: scope} do
    page = scope |> Page.ensure!(unique_slug())
    main_room = "#{page.id}/main"
    caption_room = "#{page.id}/caption-1"
    main_socket = scope |> join_channel(main_room)
    caption_socket = scope |> join_channel(caption_room)
    {:ok, main_shared_doc} = scope |> Collaboration.open_document(main_room)
    {:ok, caption_shared_doc} = scope |> Collaboration.open_document(caption_room)
    main_monitor = Process.monitor(main_shared_doc)
    caption_monitor = Process.monitor(caption_shared_doc)

    push(main_socket, "yjs", {:binary, document_update_message("main text")})
    push(caption_socket, "yjs", {:binary, document_update_message("caption text")})
    close_channel(main_socket)
    close_channel(caption_socket)
    assert_receive {:DOWN, ^main_monitor, :process, ^main_shared_doc, :normal}
    assert_receive {:DOWN, ^caption_monitor, :process, ^caption_shared_doc, :normal}

    assert scope |> persisted_text(main_room) == "main text"
    assert scope |> persisted_text(caption_room) == "caption text"
  end

  test "semantic checkpoints save changed active documents and skip unchanged ones", %{
    scope: scope
  } do
    page = scope |> Page.ensure!(unique_slug())
    main_room = "#{page.id}/main"
    caption_room = "#{page.id}/caption-1"
    {:ok, main_shared_doc} = scope |> Collaboration.open_document(main_room)
    {:ok, caption_shared_doc} = scope |> Collaboration.open_document(caption_room)
    :ok = SharedDoc.observe(main_shared_doc)
    :ok = SharedDoc.observe(caption_shared_doc)

    :ok =
      SharedDoc.update_doc(main_shared_doc, fn doc ->
        doc |> Yex.Doc.get_text("content") |> Yex.Text.insert(0, "main")
      end)

    :ok =
      SharedDoc.update_doc(caption_shared_doc, fn doc ->
        doc |> Yex.Doc.get_text("content") |> Yex.Text.insert(0, "caption")
      end)

    documents = [
      document_snapshot("main", "Main"),
      document_snapshot("caption-1", "Caption")
    ]

    assert {:ok, %{revision: :saved, saved: 2, unchanged: 0}} =
             scope |> Collaboration.checkpoint(page, documents)

    assert {:ok, %{revision: :unchanged, saved: 0, unchanged: 2}} =
             scope |> Collaboration.checkpoint(page, documents)

    page_documents = PageDocument |> Ash.Query.sort(:document_key) |> Ash.read!()

    assert Enum.map(page_documents, & &1.document_key) == ["caption-1", "main"]
    assert Enum.map(page_documents, & &1.search_text) == ["Caption", "Main"]

    assert [revision] = Ash.read!(PageRevision)
    assert revision.lexical_state == document_snapshot("main", "Main")["lexical_state"]
    assert revision.search_text == "Caption\nMain"

    main_monitor = Process.monitor(main_shared_doc)
    caption_monitor = Process.monitor(caption_shared_doc)
    :ok = Collaboration.close_document(main_shared_doc)
    :ok = Collaboration.close_document(caption_shared_doc)
    assert_receive {:DOWN, ^main_monitor, :process, ^main_shared_doc, :normal}
    assert_receive {:DOWN, ^caption_monitor, :process, ^caption_shared_doc, :normal}
  end

  test "update confirmation acknowledges preceding document updates", %{scope: scope} do
    room = unique_room(scope)
    socket = scope |> join_channel(room)

    push(socket, "yjs", {:binary, document_update_message("before confirmation")})
    reference = push(socket, "confirm_updates_applied", %{})
    assert_reply reference, :ok, %{}

    assert {:ok, shared_doc} = scope |> Collaboration.open_document(room)
    doc = SharedDoc.get_doc(shared_doc)
    assert doc |> Yex.Doc.get_text("content") |> Yex.Text.to_string() == "before confirmation"

    monitor = Process.monitor(shared_doc)
    close_channel(socket)
    assert_receive {:DOWN, ^monitor, :process, ^shared_doc, :normal}
  end

  test "semantic checkpointing requires active document rooms", %{scope: scope} do
    page = scope |> Page.ensure!(unique_slug())

    assert {:error, {:document_checkpoint_failed, "main", :document_not_open}} =
             scope
             |> Collaboration.checkpoint(page, [document_snapshot("main", "Missing")])
  end

  test "awareness is not included in the persisted document", %{scope: scope} do
    room = unique_room(scope)
    socket = scope |> join_channel(room)
    {:ok, shared_doc} = scope |> Collaboration.open_document(room)
    monitor = Process.monitor(shared_doc)
    doc = Yex.Doc.new()
    {:ok, awareness} = Yex.Awareness.new(doc)
    :ok = Yex.Awareness.set_local_state(awareness, %{"name" => "Guest"})
    {:ok, awareness_update} = Yex.Awareness.encode_update(awareness)
    awareness_message = Sync.message_encode!({:awareness, awareness_update})

    push(socket, "yjs", {:binary, awareness_message})
    close_channel(socket)
    assert_receive {:DOWN, ^monitor, :process, ^shared_doc, :normal}

    assert scope |> persisted_text(room) == ""
  end

  test "invalid and nonexistent page rooms cannot join", %{scope: scope} do
    assert {:error, %{reason: ":invalid_room"}} = scope |> join_error("not-a-page/main")

    page = scope |> Page.ensure!(unique_slug())
    assert {:error, %{reason: ":invalid_room"}} = scope |> join_error("#{page.id}/")

    document_key = String.duplicate("x", 256)

    assert {:error, %{reason: ":invalid_room"}} =
             scope |> join_error("#{page.id}/#{document_key}")

    missing_page_id = Ash.UUIDv7.generate()

    assert {:error, %{reason: ":page_not_found"}} =
             scope |> join_error("#{missing_page_id}/main")
  end

  test "a corrupt checkpoint prevents the room from opening", %{scope: scope} do
    page = scope |> Page.ensure!(unique_slug())

    PageDocument
    |> Ash.Changeset.for_create(:save, %{
      page_id: page.id,
      document_key: "main",
      yjs_state: <<255>>
    })
    |> Ash.create!()

    assert {:error, %{reason: reason}} = scope |> join_error("#{page.id}/main")
    assert reason =~ "could not restore Yjs document"
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

  defp document_snapshot(document_key, text) do
    %{
      "document_key" => document_key,
      "lexical_state" => %{
        "root" => %{
          "children" => [],
          "text" => text,
          "type" => "root",
          "version" => 1
        }
      },
      "search_text" => text
    }
  end

  defp join_channel(scope, room) do
    LexWeb.CollaborationSocket
    |> socket(nil, %{scope: scope})
    |> subscribe_and_join!(LexWeb.CollaborationChannel, "y_doc:#{room}")
  end

  defp join_error(scope, room) do
    LexWeb.CollaborationSocket
    |> socket(nil, %{scope: scope})
    |> subscribe_and_join(LexWeb.CollaborationChannel, "y_doc:#{room}")
  end

  defp sync_step1_message do
    doc = Yex.Doc.new()
    {:ok, step1} = Sync.get_sync_step1(doc)
    Sync.message_encode!({:sync, step1})
  end

  defp unique_room(scope) do
    page = scope |> Page.ensure!(unique_slug())
    "#{page.id}/main"
  end

  defp unique_slug do
    "test-#{System.unique_integer([:positive])}"
  end

  defp checkpoint_count(room) do
    [page_id, document_key] = String.split(room, "/", parts: 2)

    PageDocument
    |> Ash.Query.filter(page_id == ^page_id and document_key == ^document_key)
    |> Ash.count!()
  end

  defp persisted_text(scope, room) do
    [page_id, document_key] = String.split(room, "/", parts: 2)
    page = Page.get!(page_id, scope: scope)
    doc = Yex.Doc.new()
    :ok = scope |> Page.restore(page, document_key, doc)
    doc |> Yex.Doc.get_text("content") |> Yex.Text.to_string()
  end

  defp assert_eventually(assertion, attempts \\ 20)

  defp assert_eventually(assertion, attempts) when attempts > 0 do
    if assertion.() do
      assert true
    else
      Process.sleep(10)
      assert_eventually(assertion, attempts - 1)
    end
  end

  defp assert_eventually(_assertion, 0), do: flunk("condition did not become true")
end
