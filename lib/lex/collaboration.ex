defmodule Lex.Collaboration do
  @moduledoc """
  Opens temporary in-memory Yjs documents used by collaboration channels.

  A room has one shared document while at least one channel observes it. The
  document exits after its last observer disconnects and is not persisted.
  """

  alias Yex.Sync.SharedDoc

  @registry __MODULE__.Registry
  @supervisor __MODULE__.DocumentSupervisor

  def open_document(room) when is_binary(room) do
    case Registry.lookup(@registry, room) do
      [{pid, _value}] ->
        {:ok, pid}

      [] ->
        start_document(room)
    end
  end

  defp start_document(room) do
    child_spec = %{
      id: {SharedDoc, room},
      restart: :temporary,
      start:
        {SharedDoc, :start_link,
         [[doc_name: room, auto_exit: true], [name: {:via, Registry, {@registry, room}}]]}
    }

    case DynamicSupervisor.start_child(@supervisor, child_spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
    end
  end
end
