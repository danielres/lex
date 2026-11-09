defmodule Lex.Collaboration do
  @moduledoc """
  Opens Yjs documents used by collaboration channels.

  A room has one shared document while at least one channel observes it. The
  document persists its state and exits after its last observer disconnects.
  """

  alias Lex.Collaboration.Contributors
  alias Lex.Collaboration.Persistence
  alias Lex.Wiki.Page
  alias Yex.Sync
  alias Yex.Sync.SharedDoc

  @empty_update <<0, 0>>
  @registry __MODULE__.Registry
  @supervisor __MODULE__.DocumentSupervisor

  def open_document(scope, room) when is_binary(room) do
    with {:ok, document_ref} <- parse_room(room),
         {:ok, page} <- scope |> load_page(document_ref.page_id) do
      document_ref = %{document_key: document_ref.document_key, page: page, scope: scope}
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

  def record_update(room, user_id, message) do
    with {:ok, {:sync, {type, update}}} when type in [:sync_step2, :sync_update] <-
           Sync.message_decode(message),
         true <- update != @empty_update do
      Contributors.record(room, user_id)
    else
      _not_document_update -> :ok
    end
  end

  def document_update?(message) do
    case Sync.message_decode(message) do
      {:ok, {:sync, {type, update}}}
      when type in [:sync_step2, :sync_update] and update != @empty_update ->
        true

      _message ->
        false
    end
  end

  def save(scope, page, documents, restored_from_revision_id \\ nil)

  def save(_scope, _page, [], _restored_from_revision_id),
    do: {:error, :missing_document_snapshots}

  def save(scope, page, documents, restored_from_revision_id) when is_list(documents) do
    with :ok <- scope |> validate_source_revision(page, restored_from_revision_id),
         {:ok, snapshots} <- snapshots(documents),
         {:ok, main_snapshot} <- main_snapshot(snapshots) do
      rooms = Enum.map(snapshots, &"#{page.id}/#{&1.document_key}")
      contributions = Contributors.capture(rooms)

      result =
        with {:ok, counts} <- save_documents(scope, page, snapshots),
             {:ok, revision} <-
               scope
               |> Page.record_revision(
                 page,
                 %{
                   contributor_ids: contributions.contributor_ids,
                   lexical_state: main_snapshot.lexical_state,
                   search_text: search_text(snapshots)
                 },
                 restored_from_revision_id
               ) do
          {:ok, Map.put(counts, :revision, revision)}
        end

      case result do
        {:ok, _counts} = success ->
          :ok = Contributors.acknowledge(contributions)
          success

        {:error, _reason} = error ->
          error
      end
    end
  end

  defp validate_source_revision(_scope, _page, nil), do: :ok

  defp validate_source_revision(scope, page, revision_id) do
    scope
    |> Page.get_revision(page, revision_id)
    |> case do
      {:ok, nil} -> {:error, :revision_not_found}
      {:ok, _revision} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp save_documents(scope, page, snapshots) do
    Enum.reduce_while(snapshots, {:ok, %{saved: 0, unchanged: 0}}, fn snapshot, result ->
      with {:ok, status} <- scope |> save_document(page, snapshot) do
        {:ok, counts} = result
        counts = Map.update!(counts, status, &(&1 + 1))
        {:cont, {:ok, counts}}
      else
        {:error, reason} ->
          error = {:document_save_failed, snapshot.document_key, reason}
          {:halt, {:error, error}}
      end
    end)
  end

  defp save_document(scope, page, snapshot) do
    with {:ok, shared_doc} <- active_document(page, snapshot.document_key) do
      doc = SharedDoc.get_doc(shared_doc)

      scope |> Page.save_document(page, snapshot.document_key, doc, snapshot)
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

  defp snapshots(documents) do
    documents
    |> Enum.reduce_while({:ok, []}, fn document, {:ok, snapshots} ->
      case snapshot(document) do
        {:ok, snapshot} -> {:cont, {:ok, [snapshot | snapshots]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, snapshots} -> {:ok, Enum.sort_by(snapshots, & &1.document_key)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp main_snapshot(snapshots) do
    case Enum.find(snapshots, &(&1.document_key == "main")) do
      nil -> {:error, :missing_main_document_snapshot}
      snapshot -> {:ok, snapshot}
    end
  end

  defp search_text(snapshots) do
    snapshots
    |> Enum.map(&String.trim(&1.search_text))
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

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

  defp load_page(scope, page_id) do
    case Page.get(page_id, not_found_error?: false, scope: scope) do
      {:ok, nil} -> {:error, :page_not_found}
      {:ok, page} -> {:ok, page}
      {:error, error} -> {:error, error}
    end
  end
end
