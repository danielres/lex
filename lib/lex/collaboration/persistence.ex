defmodule Lex.Collaboration.Persistence do
  @behaviour Yex.Sync.SharedDoc.PersistenceBehaviour

  require Logger

  alias Lex.Wiki.Page

  @impl true
  def bind(document_ref, _room, doc) do
    case Page.restore(document_ref.page, document_ref.document_key, doc) do
      :ok ->
        document_ref

      {:error, reason} ->
        raise "could not restore Yjs document: #{inspect(reason)}"
    end
  end

  @impl true
  def unbind(document_ref, room, doc) do
    with :ok <- Page.set_checkpoint(document_ref.page, document_ref.document_key, doc) do
      :ok
    else
      {:error, error} ->
        Logger.error(
          "Could not checkpoint collaboration room #{inspect(room)}: #{inspect(error)}"
        )

        :ok
    end
  end
end
