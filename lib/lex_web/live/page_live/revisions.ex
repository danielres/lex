defmodule LexWeb.PageLive.Revisions do
  use LexWeb, :live_view
  use LiveDelegate, path: [:revisions]

  alias Lex.Collaboration
  alias Lex.Wiki.Page

  def on_mount(_params, _session, socket) do
    delegate_assign(socket, %{
      entries: [],
      requested_id: nil,
      restoring?: false,
      selected: nil,
      selected_index: nil
    })
  end

  def reload(socket, page, revision_id \\ nil) do
    entries = Page.list_revisions!(page)
    selected = select_revision!(entries, revision_id)
    selected_index = selected_index(entries, selected)

    socket
    |> delegate_assign(:entries, entries)
    |> delegate_assign(:requested_id, revision_id)
    |> delegate_assign(:selected, selected)
    |> delegate_assign(:selected_index, selected_index)
  end

  def checkpoint_event, do: delegate_event("checkpoint")
  def preserve_event, do: delegate_event("preserve")
  def restore_request_event, do: "revision_restore_requested"

  def previous(revisions) do
    if revisions.selected_index < length(revisions.entries) - 1 do
      Enum.at(revisions.entries, revisions.selected_index + 1)
    end
  end

  def next(revisions) do
    if revisions.selected_index > 0 do
      Enum.at(revisions.entries, revisions.selected_index - 1)
    end
  end

  def position(%{selected_index: nil}), do: nil
  def position(revisions), do: length(revisions.entries) - revisions.selected_index

  @impl true
  def handle_event("restore", _params, socket) do
    revision = socket.assigns.revisions.selected

    socket =
      socket
      |> delegate_assign(:restoring?, true)
      |> push_event(restore_request_event(), %{
        lexical_state: revision.lexical_state,
        revision_id: revision.id
      })

    {:noreply, socket}
  end

  def handle_event(
        "checkpoint",
        %{"documents" => documents, "revision_id" => revision_id},
        socket
      )
      when is_list(documents) do
    page = socket.assigns.page

    case Collaboration.checkpoint(page, documents, revision_id) do
      {:ok, _result} ->
        socket =
          socket
          |> delegate_assign(:restoring?, false)
          |> put_flash(:info, "Revision restored")
          |> push_patch(to: ~p"/wiki/#{page.slug}")

        {:reply, %{ok: true}, socket}

      {:error, _reason} ->
        restore_failed(socket)
    end
  end

  def handle_event("checkpoint", _params, socket), do: restore_failed(socket)

  def handle_event("preserve", %{"documents" => documents}, socket)
      when is_list(documents) do
    case Collaboration.checkpoint(socket.assigns.page, documents) do
      {:ok, _result} ->
        {:reply, %{ok: true}, socket}

      {:error, _reason} ->
        restore_failed(socket)
    end
  end

  def handle_event("preserve", _params, socket), do: restore_failed(socket)

  defp restore_failed(socket) do
    socket =
      socket
      |> delegate_assign(:restoring?, false)
      |> put_flash(:error, "Could not restore the revision")

    {:reply, %{ok: false}, socket}
  end

  defp select_revision!([], nil), do: nil
  defp select_revision!([revision | _revisions], nil), do: revision

  defp select_revision!(revisions, revision_id) do
    Enum.find(revisions, &(&1.id == revision_id)) ||
      raise Ash.Error.Query.NotFound,
        resource: Lex.Wiki.PageRevision,
        primary_key: %{id: revision_id}
  end

  defp selected_index(_entries, nil), do: nil
  defp selected_index(entries, selected), do: Enum.find_index(entries, &(&1.id == selected.id))
end
