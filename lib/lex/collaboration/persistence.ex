defmodule Lex.Collaboration.Persistence do
  @behaviour Yex.Sync.SharedDoc.PersistenceBehaviour

  require Logger

  alias Lex.Wiki.Page

  @impl true
  def bind(document_ref, _room, doc) do
    scope = document_ref.scope
    page = document_ref.page
    document_key = document_ref.document_key

    scope
    |> Page.restore(page, document_key, doc)
    |> case do
      :ok ->
        document_ref

      {:error, reason} ->
        raise "could not restore Yjs document: #{inspect(reason)}"
    end
  end

  @impl true
  def unbind(document_ref, room, doc) do
    scope = document_ref.scope
    page = document_ref.page
    document_key = document_ref.document_key

    scope
    |> Page.set_checkpoint(page, document_key, doc)
    |> case do
      :ok ->
        :ok

      {:error, error} ->
        Logger.error(
          "Could not checkpoint collaboration room #{inspect(room)}: #{inspect(error)}"
        )

        :ok
    end
  end
end
