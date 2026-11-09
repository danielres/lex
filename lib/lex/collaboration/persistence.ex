defmodule Lex.Collaboration.Persistence do
  @behaviour Yex.Sync.SharedDoc.PersistenceBehaviour

  require Logger

  alias Lex.Wiki.Page

  @impl true
  def bind(document_ref, _room, doc) do
    page = document_ref.page
    document_key = document_ref.document_key

    page
    |> Page.restore_collaboration_document(document_key, doc)
    |> case do
      :ok ->
        document_ref

      {:error, reason} ->
        raise "could not restore Yjs document: #{inspect(reason)}"
    end
  end

  @impl true
  def unbind(document_ref, room, doc) do
    page = document_ref.page
    document_key = document_ref.document_key

    page
    |> Page.persist_collaboration_document(document_key, doc)
    |> case do
      :ok ->
        :ok

      {:error, error} ->
        Logger.error("Could not persist collaboration room #{inspect(room)}: #{inspect(error)}")

        :ok
    end
  end
end
