defmodule Lex.Collaboration.Persistence do
  @behaviour Yex.Sync.SharedDoc.PersistenceBehaviour

  require Logger

  alias Lex.Wiki.Page

  @max_save_attempts 3

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
    with :ok <- save(document_ref, doc, 1) do
      :ok
    else
      {:error, error} ->
        Logger.error(
          "Could not checkpoint collaboration room #{inspect(room)}: #{inspect(error)}"
        )

        :ok
    end
  end

  defp save(document_ref, doc, attempt) do
    case Page.set_checkpoint(document_ref.page, document_ref.document_key, doc) do
      :ok ->
        :ok

      {:error, error} when attempt < @max_save_attempts ->
        if sqlite_busy?(error) do
          Process.sleep(attempt * 25)
          save(document_ref, doc, attempt + 1)
        else
          {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp sqlite_busy?(error) do
    error
    |> inspect()
    |> String.downcase()
    |> String.contains?("busy")
  end
end
