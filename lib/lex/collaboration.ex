defmodule Lex.Collaboration do
  @moduledoc """
  Opens Yjs documents used by collaboration channels.

  A room has one shared document while at least one channel observes it. The
  document checkpoints its state and exits after its last observer disconnects.
  """

  alias Lex.Collaboration.Persistence
  alias Lex.Wiki.Page
  alias Yex.Sync.SharedDoc

  @registry __MODULE__.Registry
  @supervisor __MODULE__.DocumentSupervisor

  def open_document(room) when is_binary(room) do
    with {:ok, document_ref} <- parse_room(room),
         {:ok, page} <- load_page(document_ref.page_id) do
      document_ref = %{document_key: document_ref.document_key, page: page}
      find_or_start_document(room, document_ref)
    end
  end

  def close_document(shared_doc) do
    with :ok <- SharedDoc.unobserve(shared_doc) do
      # Removing awareness can cancel SharedDoc's zero-timeout auto-exit check.
      send(shared_doc, :timeout)
      :ok
    end
  end

  def checkpoint(_page, []), do: {:error, :missing_document_snapshots}

  def checkpoint(page, documents) when is_list(documents) do
    Enum.reduce_while(documents, {:ok, %{saved: 0, unchanged: 0}}, fn document, result ->
      with {:ok, snapshot} <- snapshot(document),
           {:ok, status} <- checkpoint_document(page, snapshot) do
        {:ok, counts} = result
        counts = Map.update!(counts, status, &(&1 + 1))
        {:cont, {:ok, counts}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp checkpoint_document(page, snapshot) do
    with {:ok, shared_doc} <- active_document(page, snapshot.document_key) do
      doc = SharedDoc.get_doc(shared_doc)
      Page.set_checkpoint(page, snapshot.document_key, doc, snapshot)
    end
  end

  defp find_or_start_document(room, document_ref) do
    case Registry.lookup(@registry, room) do
      [{pid, _value}] ->
        if Process.alive?(pid) do
          {:ok, pid}
        else
          start_document(room, document_ref)
        end

      [] ->
        start_document(room, document_ref)
    end
  end

  defp active_document(page, document_key) do
    room = "#{page.id}/#{document_key}"

    case Registry.lookup(@registry, room) do
      [{pid, _value}] -> {:ok, pid}
      [] -> {:error, :document_not_open}
    end
  end

  defp snapshot(%{
         "document_key" => document_key,
         "lexical_state" => lexical_state,
         "search_text" => search_text
       })
       when is_binary(document_key) and is_map(lexical_state) and is_binary(search_text) do
    {:ok,
     %{
       document_key: document_key,
       lexical_state: lexical_state,
       search_text: search_text
     }}
  end

  defp snapshot(_document), do: {:error, :invalid_document_snapshot}

  defp start_document(room, document_ref) do
    child_spec = %{
      id: {SharedDoc, room},
      restart: :temporary,
      start:
        {SharedDoc, :start_link,
         [
           [
             doc_name: room,
             auto_exit: true,
             persistence: {Persistence, document_ref}
           ],
           [name: {:via, Registry, {@registry, room}}]
         ]}
    }

    case DynamicSupervisor.start_child(@supervisor, child_spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_room(room) do
    with [page_id, document_key] <- String.split(room, "/", parts: 2),
         {:ok, page_id} <- Ecto.UUID.cast(page_id),
         true <- document_key != "" and String.length(document_key) <= 255 do
      {:ok, %{document_key: document_key, page_id: page_id}}
    else
      _error -> {:error, :invalid_room}
    end
  end

  defp load_page(page_id) do
    case Page.get(page_id, not_found_error?: false) do
      {:ok, nil} -> {:error, :page_not_found}
      {:ok, page} -> {:ok, page}
      {:error, error} -> {:error, error}
    end
  end
end
